namespace SmartHealthFitness.Api.Entities;

public enum WorkoutSessionStatus { Planned, InProgress, Completed, Cancelled }

public sealed class WorkoutSession
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public Guid WorkoutPlanId { get; set; }
    public Guid WorkoutDayId { get; set; }
    public DateTime StartedAt { get; set; } = DateTime.UtcNow;
    public DateTime? CompletedAt { get; set; }
    public WorkoutSessionStatus Status { get; set; } = WorkoutSessionStatus.InProgress;
    public string? Notes { get; set; }
    public User User { get; set; } = null!;
    public WorkoutPlan WorkoutPlan { get; set; } = null!;
    public WorkoutDay WorkoutDay { get; set; } = null!;
    public ICollection<WorkoutLog> Logs { get; set; } = [];
}

public sealed class WorkoutLog
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid WorkoutSessionId { get; set; }
    public Guid WorkoutExerciseId { get; set; }
    public int? CompletedSets { get; set; }
    public int? CompletedReps { get; set; }
    public decimal? WeightKg { get; set; }
    public int? DurationSeconds { get; set; }
    public bool IsCompleted { get; set; }
    public string? Notes { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public WorkoutSession WorkoutSession { get; set; } = null!;
    public WorkoutExercise WorkoutExercise { get; set; } = null!;
}
