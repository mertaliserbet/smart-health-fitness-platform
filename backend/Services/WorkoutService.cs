using Microsoft.EntityFrameworkCore;
using SmartHealthFitness.Api.Contracts;
using SmartHealthFitness.Api.Data;
using SmartHealthFitness.Api.Entities;

namespace SmartHealthFitness.Api.Services;

public sealed class WorkoutService(AppDbContext dbContext, AdvisorService advisorService)
{
    public Task<ExerciseResponse[]> GetExercisesAsync(string? search, CancellationToken ct) =>
        dbContext.Exercises.AsNoTracking().Where(exercise => exercise.IsActive &&
            (search == null || EF.Functions.ILike(exercise.Name, "%" + search + "%")))
            .OrderBy(exercise => exercise.Name).ThenBy(exercise => exercise.Id)
            .Select(exercise => new ExerciseResponse(exercise.Id, exercise.Name, exercise.Description,
                exercise.Instructions, exercise.VideoUrl, exercise.ImageUrl)).ToArrayAsync(ct);

    public async Task<WorkoutPlanResponse> CreatePlanAsync(Guid userId, Guid trainerId,
        CreateWorkoutPlanRequest request, CancellationToken ct)
    {
        await using var transaction = await dbContext.Database.BeginTransactionAsync(ct);
        await advisorService.LockClientAsync(userId, trainerId, AdvisorType.Trainer, ct);
        var exerciseIds = request.Days.SelectMany(day => day.Exercises).Select(item => item.ExerciseId).Distinct().ToArray();
        // Protect the selected catalog entries against deactivation/deletion until this assignment commits.
        var catalog = await dbContext.Exercises.FromSqlInterpolated($"SELECT * FROM exercises WHERE id = ANY({exerciseIds}) FOR SHARE")
            .AsNoTracking().ToArrayAsync(ct);
        if (catalog.Count(exercise => exercise.IsActive) != exerciseIds.Length)
            throw new AssignmentException(400, "Geçersiz veya pasif egzersiz seçildi.",
                new() { ["days"] = ["Tüm egzersizler aktif katalogdan seçilmeli."] });
        await dbContext.WorkoutPlans.Where(plan => plan.UserId == userId && plan.IsActive)
            .ExecuteUpdateAsync(setters => setters.SetProperty(plan => plan.IsActive, false)
                .SetProperty(plan => plan.UpdatedAt, DateTime.UtcNow), ct);
        var plan = new WorkoutPlan { UserId = userId, TrainerId = trainerId, Name = request.Name.Trim(),
            Description = request.Description?.Trim(), StartDate = request.StartDate, EndDate = request.EndDate,
            Days = request.Days.Select(day => new WorkoutDay { Name = day.Name.Trim(), DayNumber = day.DayNumber,
                Weekday = Enum.Parse<Weekday>(day.Weekday), Description = day.Description?.Trim(),
                Exercises = day.Exercises.Select(item => new WorkoutExercise { ExerciseId = item.ExerciseId,
                    Order = item.Order, Sets = item.Sets, Reps = item.Reps, DurationSeconds = item.DurationSeconds,
                    RestSeconds = item.RestSeconds, WeightKg = item.WeightKg, Notes = item.Notes?.Trim() }).ToArray()
            }).ToArray() };
        dbContext.WorkoutPlans.Add(plan);
        await dbContext.SaveChangesAsync(ct);
        var response = (await GetWorkoutPlanAsync(plan.Id, trainerId, false, true, ct))!;
        await transaction.CommitAsync(ct);
        return response;
    }

    public Task<WorkoutPlanSummaryResponse[]> GetWorkoutPlansAsync(Guid userId, CancellationToken cancellationToken) =>
        dbContext.WorkoutPlans.AsNoTracking().Where(plan => plan.UserId == userId)
            .OrderByDescending(plan => plan.IsActive).ThenByDescending(plan => plan.StartDate).ThenBy(plan => plan.Id)
            .Select(plan => new WorkoutPlanSummaryResponse(plan.Id, plan.Name, plan.StartDate, plan.EndDate, plan.IsActive))
            .ToArrayAsync(cancellationToken);

    public async Task<WorkoutPlanResponse?> GetWorkoutPlanAsync(Guid planId, Guid currentUserId,
        bool canReadOwn, bool isTrainer, CancellationToken cancellationToken)
    {
        // Apply access in the query, before loading any days or exercises.
        var plan = await dbContext.WorkoutPlans.AsNoTracking()
            .Where(plan => plan.Id == planId && ((canReadOwn && plan.UserId == currentUserId)
                || (isTrainer && dbContext.UserAdvisors.Any(relation => relation.UserId == plan.UserId
                    && relation.AdvisorId == currentUserId && relation.AdvisorType == AdvisorType.Trainer
                    && relation.Status == UserAdvisorStatus.Active))))
            .Include(plan => plan.Days).ThenInclude(day => day.Exercises).ThenInclude(item => item.Exercise)
            .AsSplitQuery().SingleOrDefaultAsync(cancellationToken);
        if (plan is null) return null;
        return new WorkoutPlanResponse(plan.Id, plan.UserId, plan.TrainerId, plan.Name, plan.Description,
            plan.StartDate, plan.EndDate, plan.IsActive,
            plan.Days.OrderBy(day => day.DayNumber).ThenBy(day => day.Id)
                .Select(day => new WorkoutDayResponse(day.Id, day.Name, day.DayNumber, day.Weekday, day.Description,
                    day.Exercises.OrderBy(item => item.Order).ThenBy(item => item.Id)
                        .Select(item => new WorkoutExerciseResponse(item.Id, item.ExerciseId, item.Exercise.Name,
                            item.Order, item.Sets, item.Reps, item.DurationSeconds, item.RestSeconds, item.WeightKg, item.Notes))
                        .ToArray())).ToArray());
    }
}
