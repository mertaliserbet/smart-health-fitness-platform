using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;
using SmartHealthFitness.Api.Validation;

namespace SmartHealthFitness.Api.Contracts;

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class CreateWorkoutPlanRequest : IValidatableObject
{
    [Required, StringLength(200)] public string Name { get; init; } = string.Empty;
    [StringLength(10000)] public string? Description { get; init; }
    [Required] public DateOnly? StartDate { get; init; }
    public DateOnly? EndDate { get; init; }
    [Required, MinLength(1), MaxLength(7)] public CreateWorkoutDayRequest[] Days { get; init; } = [];

    public IEnumerable<ValidationResult> Validate(ValidationContext context)
    {
        if (EndDate < StartDate) yield return new("Bitiş tarihi başlangıçtan önce olamaz.", ["endDate"]);
        if (Days is null) yield break;
        if (Days.Any(day => day is null))
        {
            yield return new("Antrenman günleri boş olamaz.", ["days"]);
            yield break;
        }
        if (Days.Select(day => day.Weekday).Distinct().Count() != Days.Length)
            yield return new("Haftanın her günü yalnızca bir kez seçilebilir.", ["days"]);
        if (Days.Select(day => day.DayNumber).Distinct().Count() != Days.Length)
            yield return new("Gün sıra numaraları benzersiz olmalıdır.", ["days"]);
    }
}

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class CreateWorkoutDayRequest : IValidatableObject
{
    [Required, StringLength(200)] public string Name { get; init; } = string.Empty;
    [Required, Range(1, int.MaxValue)] public int? DayNumber { get; init; }
    [Required, RegularExpression("^(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)$")]
    public string Weekday { get; init; } = string.Empty;
    [StringLength(10000)] public string? Description { get; init; }
    [Required, MinLength(1), MaxLength(100)] public CreateWorkoutExerciseRequest[] Exercises { get; init; } = [];

    public IEnumerable<ValidationResult> Validate(ValidationContext context)
    {
        if (Exercises is null) yield break;
        if (Exercises.Any(item => item is null))
            yield return new("Egzersizler boş olamaz.", ["exercises"]);
        else if (Exercises.Select(item => item.Order).Distinct().Count() != Exercises.Length)
            yield return new("Egzersiz sıra numaraları benzersiz olmalıdır.", ["exercises"]);
    }
}

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public class CreateWorkoutExerciseRequest : IValidatableObject
{
    [Required] public Guid? ExerciseId { get; init; }
    [Required, Range(1, int.MaxValue)] public int? Order { get; init; }
    [Range(1, int.MaxValue)] public int? Sets { get; init; }
    [Range(1, int.MaxValue)] public int? Reps { get; init; }
    [Range(1, int.MaxValue)] public int? DurationSeconds { get; init; }
    [Range(0, int.MaxValue)] public int? RestSeconds { get; init; }
    [TrackingValue("0", "99999999.99")] public decimal? WeightKg { get; init; }
    [StringLength(10000)] public string? Notes { get; init; }

    public IEnumerable<ValidationResult> Validate(ValidationContext context)
    {
        if (ExerciseId == Guid.Empty) yield return new("Geçerli bir egzersiz seçin.", ["exerciseId"]);
        if (DurationSeconds is null && (Sets is null || Reps is null))
            yield return new("Set/tekrar veya süre hedefi girin.", ["sets", "reps", "durationSeconds"]);
        if (DurationSeconds is not null && (Sets is not null || Reps is not null))
            yield return new("Set/tekrar ve süre hedeflerinden birini seçin.", ["durationSeconds"]);
    }
}

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class UpdateWorkoutPlanRequest : IValidatableObject
{
    // Null is the revision of a newly created plan; omitting the field is an error.
    [JsonRequired] public DateTimeOffset? ExpectedUpdatedAt { get; init; }
    [Required, StringLength(200)] public string Name { get; init; } = string.Empty;
    [StringLength(10000)] public string? Description { get; init; }
    [Required] public DateOnly? StartDate { get; init; }
    public DateOnly? EndDate { get; init; }
    [Required, MinLength(1), MaxLength(7)] public UpdateWorkoutDayRequest[] Days { get; init; } = [];

    public IEnumerable<ValidationResult> Validate(ValidationContext context) =>
        new CreateWorkoutPlanRequest { StartDate = StartDate, EndDate = EndDate,
            Days = Days?.Select(day => day?.AsCreateRequest()!).ToArray()! }.Validate(context);
}

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class UpdateWorkoutDayRequest : IValidatableObject
{
    public Guid? Id { get; init; }
    [Required, StringLength(200)] public string Name { get; init; } = string.Empty;
    [Required, Range(1, int.MaxValue)] public int? DayNumber { get; init; }
    [Required, RegularExpression("^(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)$")]
    public string Weekday { get; init; } = string.Empty;
    [StringLength(10000)] public string? Description { get; init; }
    [Required, MinLength(1), MaxLength(100)] public UpdateWorkoutExerciseRequest[] Exercises { get; init; } = [];

    public CreateWorkoutDayRequest AsCreateRequest() => new() { Name = Name, DayNumber = DayNumber,
        Weekday = Weekday, Description = Description, Exercises = Exercises };

    public IEnumerable<ValidationResult> Validate(ValidationContext context) => AsCreateRequest().Validate(context);
}

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class UpdateWorkoutExerciseRequest : CreateWorkoutExerciseRequest
{
    public Guid? Id { get; init; }
}
