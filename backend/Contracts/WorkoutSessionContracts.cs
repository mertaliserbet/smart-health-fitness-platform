using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;
using SmartHealthFitness.Api.Entities;
using SmartHealthFitness.Api.Validation;

namespace SmartHealthFitness.Api.Contracts;

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class StartWorkoutSessionRequest : IValidatableObject
{
    [Required] public Guid? WorkoutPlanId { get; init; }
    [Required] public Guid? WorkoutDayId { get; init; }
    public IEnumerable<ValidationResult> Validate(ValidationContext context)
    {
        if (WorkoutPlanId == Guid.Empty) yield return new("Geçerli bir program seçin.", ["workoutPlanId"]);
        if (WorkoutDayId == Guid.Empty) yield return new("Geçerli bir antrenman günü seçin.", ["workoutDayId"]);
    }
}

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class SaveWorkoutLogRequest
{
    [Range(0, int.MaxValue)] public int? CompletedSets { get; init; }
    [Range(0, int.MaxValue)] public int? CompletedReps { get; init; }
    [TrackingValue("0", "99999999.99")] public decimal? WeightKg { get; init; }
    [Range(0, int.MaxValue)] public int? DurationSeconds { get; init; }
    [Required] public bool? IsCompleted { get; init; }
    [StringLength(10000)] public string? Notes { get; init; }
}

public sealed class WorkoutSessionQuery
{
    [Range(1, 1000000)] public int Page { get; init; } = 1;
    [Range(1, 100)] public int PageSize { get; init; } = 20;
    [RegularExpression("^(InProgress|Completed|Cancelled)$")] public string? Status { get; init; }
}

public sealed record WorkoutSessionSummaryResponse(Guid Id, Guid UserId, Guid WorkoutPlanId,
    Guid WorkoutDayId, string PlanName, string DayName, DateTime StartedAt, DateTime? CompletedAt,
    WorkoutSessionStatus Status, int CompletedExerciseCount, int TotalExerciseCount);

public sealed record PagedWorkoutSessionsResponse(WorkoutSessionSummaryResponse[] Items, int Page,
    int PageSize, int TotalCount, int TotalPages);

public sealed record WorkoutSessionResponse(Guid Id, Guid UserId, Guid WorkoutPlanId,
    Guid WorkoutDayId, string PlanName, DateTime StartedAt, DateTime? CompletedAt,
    WorkoutSessionStatus Status, WorkoutDayResponse Day, WorkoutLogResponse[] Logs);

public sealed record WorkoutLogResponse(Guid Id, Guid WorkoutExerciseId, int? CompletedSets,
    int? CompletedReps, decimal? WeightKg, int? DurationSeconds, bool IsCompleted, string? Notes,
    DateTime CreatedAt);
