using SmartHealthFitness.Api.Entities;

namespace SmartHealthFitness.Api.Contracts;

public sealed record UserAdvisorResponse(Guid UserAdvisorId, Guid AdvisorId, AdvisorType AdvisorType,
    string FirstName, string LastName, string? Title, string? Specialization,
    UserAdvisorStatus Status, DateOnly StartDate, DateOnly? EndDate);

public sealed record AdvisorNoteResponse(Guid Id, Guid UserId, Guid AdvisorId,
    string Title, string Content, DateTime CreatedAt, DateTime? UpdatedAt);

public sealed record UserTaskResponse(Guid Id, Guid UserId, Guid AdvisorId, string Title,
    string? Description, DateOnly? DueDate, UserTaskStatus Status, DateTime? CompletedAt,
    DateTime CreatedAt, DateTime? UpdatedAt);

public sealed record WorkoutPlanSummaryResponse(Guid Id, string Name, DateOnly StartDate,
    DateOnly? EndDate, bool IsActive);

public sealed record WorkoutPlanResponse(Guid Id, Guid UserId, Guid TrainerId, string Name,
    string? Description, DateOnly StartDate, DateOnly? EndDate, bool IsActive, WorkoutDayResponse[] Days,
    DateTime? UpdatedAt, bool HasSessions);

public sealed record WorkoutDayResponse(Guid Id, string Name, int DayNumber, Weekday Weekday,
    string? Description, WorkoutExerciseResponse[] Exercises);

public sealed record WorkoutExerciseResponse(Guid Id, Guid ExerciseId, string ExerciseName,
    int Order, int? Sets, int? Reps, int? DurationSeconds, int? RestSeconds, decimal? WeightKg, string? Notes);

public sealed record NutritionGoalResponse(Guid Id, decimal DailyCalories, decimal ProteinGrams,
    decimal CarbohydrateGrams, decimal FatGrams, decimal WaterMl, bool IsActive,
    DateOnly StartDate, DateOnly? EndDate);
