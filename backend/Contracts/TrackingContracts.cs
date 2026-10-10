using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;
using SmartHealthFitness.Api.Entities;
using SmartHealthFitness.Api.Validation;

namespace SmartHealthFitness.Api.Contracts;

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class CreateWeightRecordRequest
{
    [Required(ErrorMessage = "Kilo zorunludur."), TrackingValue("0.01", "1000")]
    public decimal? WeightKg { get; init; }
    [Required(ErrorMessage = "Kayıt zamanı zorunludur."), PastOrPresent]
    public DateTimeOffset? RecordedAt { get; init; }
}

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class CreateBodyMeasurementRequest : IValidatableObject
{
    [TrackingValue("0.01", "1000")] public decimal? ChestCm { get; init; }
    [TrackingValue("0.01", "1000")] public decimal? WaistCm { get; init; }
    [TrackingValue("0.01", "1000")] public decimal? HipCm { get; init; }
    [TrackingValue("0.01", "1000")] public decimal? ArmCm { get; init; }
    [TrackingValue("0.01", "1000")] public decimal? ThighCm { get; init; }
    [TrackingValue("0", "100")] public decimal? BodyFatPercentage { get; init; }
    [Required(ErrorMessage = "Kayıt zamanı zorunludur."), PastOrPresent]
    public DateTimeOffset? RecordedAt { get; init; }

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (new[] { ChestCm, WaistCm, HipCm, ArmCm, ThighCm, BodyFatPercentage }.All(value => value is null))
            yield return new ValidationResult("En az bir vücut ölçümü girin.", ["measurements"]);
    }
}

public sealed record WeightRecordResponse(Guid Id, decimal WeightKg, DateTime RecordedAt)
{
    public static WeightRecordResponse FromRecord(WeightRecord record) =>
        new(record.Id, record.WeightKg, record.RecordedAt);
}

public sealed record BodyMeasurementResponse(Guid Id, decimal? ChestCm, decimal? WaistCm,
    decimal? HipCm, decimal? ArmCm, decimal? ThighCm, decimal? BodyFatPercentage, DateTime RecordedAt)
{
    public static BodyMeasurementResponse FromRecord(BodyMeasurement record) => new(record.Id,
        record.ChestCm, record.WaistCm, record.HipCm, record.ArmCm, record.ThighCm,
        record.BodyFatPercentage, record.RecordedAt);
}
