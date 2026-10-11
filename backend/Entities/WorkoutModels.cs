namespace SmartHealthFitness.Api.Entities;

public enum Weekday { Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday }

public sealed class Exercise
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string? Instructions { get; set; }
    public string? VideoUrl { get; set; }
    public string? ImageUrl { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAt { get; set; }
}

public sealed class WorkoutPlan
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public Guid TrainerId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public DateOnly StartDate { get; set; }
    public DateOnly? EndDate { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAt { get; set; }
    public User User { get; set; } = null!;
    public User Trainer { get; set; } = null!;
    public ICollection<WorkoutDay> Days { get; set; } = new List<WorkoutDay>();
}

public sealed class WorkoutDay
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid WorkoutPlanId { get; set; }
    public string Name { get; set; } = string.Empty;
    public int DayNumber { get; set; }
    public Weekday Weekday { get; set; }
    public string? Description { get; set; }
    public WorkoutPlan WorkoutPlan { get; set; } = null!;
    public ICollection<WorkoutExercise> Exercises { get; set; } = new List<WorkoutExercise>();
}

public sealed class WorkoutExercise
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid WorkoutDayId { get; set; }
    public Guid ExerciseId { get; set; }
    public int Order { get; set; }
    public int? Sets { get; set; }
    public int? Reps { get; set; }
    public int? DurationSeconds { get; set; }
    public int? RestSeconds { get; set; }
    public decimal? WeightKg { get; set; }
    public string? Notes { get; set; }
    public WorkoutDay WorkoutDay { get; set; } = null!;
    public Exercise Exercise { get; set; } = null!;
}
