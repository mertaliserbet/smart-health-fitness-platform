using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;
using SmartHealthFitness.Api.Entities;
using SmartHealthFitness.Api.Validation;

namespace SmartHealthFitness.Api.Contracts;

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class CreateWorkoutPlanRequest : IValidatableObject
{
    [Required, StringLength(200)] public string Name { get; init; } = string.Empty;
    public string? Description { get; init; }
    [JsonRequired] public DateOnly StartDate { get; init; }
    public DateOnly? EndDate { get; init; }
    [Required, MinLength(1), MaxLength(7)] public WorkoutDayRequest[] Days { get; init; } = [];
    public IEnumerable<ValidationResult> Validate(ValidationContext context)
    {
        if (StartDate == default) yield return new("Başlangıç tarihi gerekli.", ["startDate"]);
        if (EndDate < StartDate) yield return new("Bitiş tarihi başlangıçtan önce olamaz.", ["endDate"]);
        if (Days is null || Days.Any(day => day is null))
        { yield return new("Geçerli antrenman günleri girin.", ["days"]); yield break; }
        if (Days.Select(day => day.Weekday).Distinct().Count() != Days.Length)
            yield return new("Aynı hafta gününe birden fazla antrenman atanamaz.", ["days"]);
        if (Days.Select(day => day.DayNumber).Distinct().Count() != Days.Length)
            yield return new("Gün sıraları benzersiz olmalı.", ["days"]);
    }
}

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class WorkoutDayRequest : IValidatableObject
{
    [Required, StringLength(200)] public string Name { get; init; } = string.Empty;
    [Range(1, int.MaxValue)] public int DayNumber { get; init; }
    [Required, RegularExpression("Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday")]
    public string Weekday { get; init; } = string.Empty;
    public string? Description { get; init; }
    [Required, MinLength(1)] public WorkoutExerciseRequest[] Exercises { get; init; } = [];
    public IEnumerable<ValidationResult> Validate(ValidationContext context)
    {
        if (Exercises is null || Exercises.Any(item => item is null))
        { yield return new("Geçerli egzersizler girin.", ["exercises"]); yield break; }
        if (Exercises.Select(item => item.Order).Distinct().Count() != Exercises.Length)
            yield return new("Egzersiz sıraları benzersiz olmalı.", ["exercises"]);
    }
}

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class WorkoutExerciseRequest : IValidatableObject
{
    [JsonRequired] public Guid ExerciseId { get; init; }
    [Range(1, int.MaxValue)] public int Order { get; init; }
    [Range(1, int.MaxValue)] public int? Sets { get; init; }
    [Range(1, int.MaxValue)] public int? Reps { get; init; }
    [Range(1, int.MaxValue)] public int? DurationSeconds { get; init; }
    [Range(0, int.MaxValue)] public int? RestSeconds { get; init; }
    [TrackingValue("0", "99999999.99")] public decimal? WeightKg { get; init; }
    public string? Notes { get; init; }
    public IEnumerable<ValidationResult> Validate(ValidationContext context)
    {
        if (ExerciseId == Guid.Empty) yield return new("Egzersiz seçin.", ["exerciseId"]);
        if (DurationSeconds is null && (Sets is null || Reps is null))
            yield return new("Set/tekrar veya süre girin.", ["sets", "reps", "durationSeconds"]);
    }
}

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class CreateNutritionGoalRequest : IValidatableObject
{
    [JsonRequired, TrackingValue("0", "9999999999.99")] public decimal DailyCalories { get; init; }
    [JsonRequired, TrackingValue("0", "9999999999.99")] public decimal ProteinGrams { get; init; }
    [JsonRequired, TrackingValue("0", "9999999999.99")] public decimal CarbohydrateGrams { get; init; }
    [JsonRequired, TrackingValue("0", "9999999999.99")] public decimal FatGrams { get; init; }
    [JsonRequired, TrackingValue("0", "9999999999.99")] public decimal WaterMl { get; init; }
    [JsonRequired] public DateOnly StartDate { get; init; }
    public DateOnly? EndDate { get; init; }
    public IEnumerable<ValidationResult> Validate(ValidationContext context)
    {
        if (StartDate == default) yield return new("Başlangıç tarihi gerekli.", ["startDate"]);
        if (EndDate < StartDate) yield return new("Bitiş tarihi başlangıçtan önce olamaz.", ["endDate"]);
    }
}

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class CreateAdvisorNoteRequest
{
    [Required, StringLength(200)] public string Title { get; init; } = string.Empty;
    [Required] public string Content { get; init; } = string.Empty;
}

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class CreateUserTaskRequest
{
    [Required, StringLength(200)] public string Title { get; init; } = string.Empty;
    public string? Description { get; init; }
    public DateOnly? DueDate { get; init; }
}

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class UpdateTaskStatusRequest
{
    [Required, RegularExpression("Pending|InProgress|Completed|Cancelled")]
    public string Status { get; init; } = string.Empty;
}

public sealed record ClientSummaryResponse(Guid Id, string FirstName, string LastName,
    UserAdvisorStatus RelationshipStatus, DateOnly StartDate);
public sealed record ExerciseResponse(Guid Id, string Name, string? Description, string? Instructions,
    string? VideoUrl, string? ImageUrl);
