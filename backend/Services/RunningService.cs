using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using SmartHealthFitness.Api.Contracts;
using SmartHealthFitness.Api.Data;
using SmartHealthFitness.Api.Entities;

namespace SmartHealthFitness.Api.Services;

public sealed class RunningService(AppDbContext db)
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public Task<RunningActivitySummaryResponse[]> GetActivitiesAsync(Guid userId, CancellationToken ct) =>
        db.RunningActivities.AsNoTracking().Where(run => run.UserId == userId)
            .OrderByDescending(run => run.StartedAt).ThenBy(run => run.Id)
            .Select(run => new RunningActivitySummaryResponse(run.Id, run.StartedAt, run.EndedAt,
                run.DurationSeconds, run.DistanceMeters, run.AveragePaceSecondsPerKm, run.AverageSpeedKmh,
                run.EstimatedCalories, run.CreatedAt)).ToArrayAsync(ct);

    public async Task<RunningActivityResponse?> GetActivityAsync(Guid userId, Guid id, CancellationToken ct)
    {
        var run = await db.RunningActivities.AsNoTracking().SingleOrDefaultAsync(run => run.Id == id && run.UserId == userId, ct);
        return run is null ? null : Response(run);
    }

    public async Task<(RunningActivityResponse Activity, bool Created)> CreateActivityAsync(Guid userId,
        CreateRunningActivityRequest request, CancellationToken ct)
    {
        var segments = request.RouteData!.Segments!;
        double distance = 0;
        foreach (var segment in segments)
            for (var index = 1; index < segment!.Length; index++)
                distance += RunningRouteData.Distance(segment[index - 1]!, segment[index]!);
        var duration = request.DurationSeconds!.Value;
        var meters = Math.Round((decimal)distance, 2);
        var candidate = new RunningActivity { Id = request.Id!.Value, UserId = userId,
            StartedAt = Microseconds(request.StartedAt!.Value), EndedAt = Microseconds(request.EndedAt!.Value),
            DurationSeconds = duration, DistanceMeters = meters,
            AveragePaceSecondsPerKm = meters == 0 ? null : Math.Round(duration * 1000m / meters, 2),
            AverageSpeedKmh = Math.Round(meters * 3.6m / duration, 2),
            RouteData = JsonSerializer.Serialize(request.RouteData, JsonOptions) };
        var existing = await db.RunningActivities.AsNoTracking().SingleOrDefaultAsync(run => run.Id == candidate.Id, ct);
        if (existing is not null) return (Replay(existing, candidate), false);
        db.RunningActivities.Add(candidate);
        try { await db.SaveChangesAsync(ct); }
        catch (DbUpdateException error) when (error.InnerException is PostgresException { SqlState: PostgresErrorCodes.UniqueViolation })
        {
            db.Entry(candidate).State = EntityState.Detached;
            existing = await db.RunningActivities.AsNoTracking().SingleAsync(run => run.Id == candidate.Id, ct);
            return (Replay(existing, candidate), false);
        }
        await db.Entry(candidate).ReloadAsync(ct);
        return (Response(candidate), true);
    }

    private static DateTime Microseconds(DateTimeOffset value) =>
        new(value.UtcTicks / 10 * 10, DateTimeKind.Utc);

    private static RunningActivityResponse Replay(RunningActivity saved, RunningActivity candidate)
    {
        // jsonb normalizes whitespace/property order; compare typed canonical JSON, not raw stored text.
        var route = JsonSerializer.Serialize(JsonSerializer.Deserialize<RunningRouteData>(saved.RouteData, JsonOptions), JsonOptions);
        if (saved.UserId != candidate.UserId || saved.StartedAt != candidate.StartedAt || saved.EndedAt != candidate.EndedAt
            || saved.DurationSeconds != candidate.DurationSeconds || route != candidate.RouteData)
            throw new AssignmentException(409, "Koşu kimliği başka bir kayıt için kullanılmış.");
        return Response(saved);
    }

    private static RunningActivityResponse Response(RunningActivity run) => new(run.Id, run.StartedAt, run.EndedAt,
        run.DurationSeconds, run.DistanceMeters, run.AveragePaceSecondsPerKm, run.AverageSpeedKmh,
        run.EstimatedCalories, JsonSerializer.Deserialize<RunningRouteData>(run.RouteData, JsonOptions)!, run.CreatedAt);
}
