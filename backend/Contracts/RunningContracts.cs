using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;
using SmartHealthFitness.Api.Validation;

namespace SmartHealthFitness.Api.Contracts;

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class CreateRunningActivityRequest : IValidatableObject
{
    [Required] public Guid? Id { get; init; }
    [Required, PastOrPresent] public DateTimeOffset? StartedAt { get; init; }
    [Required, PastOrPresent] public DateTimeOffset? EndedAt { get; init; }
    [Required, Range(1, 86400)] public int? DurationSeconds { get; init; }
    [Required] public RunningRouteData? RouteData { get; init; }

    public IEnumerable<ValidationResult> Validate(ValidationContext context)
    {
        if (Id == Guid.Empty) yield return new("Koşu kimliği boş olamaz.", ["id"]);
        if (StartedAt is not null && EndedAt is not null &&
            (EndedAt < StartedAt || DurationSeconds > (EndedAt.Value - StartedAt.Value).TotalSeconds))
            yield return new("Aktif süre toplam zaman aralığını aşamaz; bitiş başlangıçtan önce olamaz.", ["durationSeconds"]);
        if (RouteData?.Segments is not { Length: > 0 } segments) yield break;
        if (segments.Sum(segment => segment?.Length ?? 0) > 20000)
            yield return new("En fazla 20000 GPS noktası kaydedilebilir.", ["routeData"]);
        DateTimeOffset? previousTime = null;
        foreach (var segment in segments)
        {
            RunningRoutePoint? previous = null;
            if (segment is not { Length: > 0 })
            {
                yield return new("Rota segmenti boş olamaz.", ["routeData"]);
                continue;
            }
            foreach (var point in segment)
            {
                if (point?.RecordedAt is not { } time) continue; // Nested Required handles missing points/times.
                if (time < StartedAt || time > EndedAt || time <= previousTime)
                    yield return new("GPS zamanları koşu aralığında ve kesin artan sırada olmalı.", ["routeData"]);
                if (previous is not null && previous.RecordedAt is { } lastTime && time > lastTime &&
                    ((time - lastTime).TotalSeconds > 15 || RunningRouteData.Distance(previous, point) / (time - lastTime).TotalSeconds > 12))
                    yield return new("Koşuyla uyumsuz GPS sıçraması var; rota segmentlerini kontrol edin.", ["routeData"]);
                previousTime = time;
                previous = point;
            }
        }
    }
}

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class RunningRoutePoint
{
    [Required, Range(-90, 90)] public double? Latitude { get; init; }
    [Required, Range(-180, 180)] public double? Longitude { get; init; }
    [Required, Range(0, 35)] public double? AccuracyMeters { get; init; }
    [Required] public DateTimeOffset? RecordedAt { get; init; }
}

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class RunningRouteData : IValidatableObject
{
    [Required, RegularExpression("gps-segments")] public string Type { get; init; } = string.Empty;
    [Required, MinLength(1), MaxLength(20000)] public RunningRoutePoint?[]?[]? Segments { get; init; }
    public IEnumerable<ValidationResult> Validate(ValidationContext context)
    {
        if (Segments?.Any(segment => segment?.Any(point => point is null) ?? false) == true)
            yield return new("GPS noktası null olamaz.", ["routeData"]);
    }

    public static double Distance(RunningRoutePoint a, RunningRoutePoint b)
    {
        if (a.Latitude is null || a.Longitude is null || b.Latitude is null || b.Longitude is null) return 0;
        const double radians = Math.PI / 180;
        var lat = (b.Latitude.Value - a.Latitude.Value) * radians;
        var lon = (b.Longitude.Value - a.Longitude.Value) * radians;
        var haversine = Math.Pow(Math.Sin(lat / 2), 2) + Math.Cos(a.Latitude.Value * radians)
            * Math.Cos(b.Latitude.Value * radians) * Math.Pow(Math.Sin(lon / 2), 2);
        return 6378137 * 2 * Math.Asin(Math.Sqrt(Math.Clamp(haversine, 0, 1)));
    }
}

public sealed record RunningActivitySummaryResponse(Guid Id, DateTime StartedAt, DateTime EndedAt,
    int DurationSeconds, decimal DistanceMeters, decimal? AveragePaceSecondsPerKm,
    decimal AverageSpeedKmh, decimal? EstimatedCalories, DateTime CreatedAt);

public sealed record RunningActivityResponse(Guid Id, DateTime StartedAt, DateTime EndedAt,
    int DurationSeconds, decimal DistanceMeters, decimal? AveragePaceSecondsPerKm,
    decimal AverageSpeedKmh, decimal? EstimatedCalories, RunningRouteData RouteData, DateTime CreatedAt);
