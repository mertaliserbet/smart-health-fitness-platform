using Microsoft.EntityFrameworkCore;
using SmartHealthFitness.Api.Contracts;
using SmartHealthFitness.Api.Data;
using SmartHealthFitness.Api.Entities;

namespace SmartHealthFitness.Api.Services;

public sealed class WorkoutService(AppDbContext dbContext, AdvisorService advisorService)
{
    public async Task<WorkoutPlanResponse> CreatePlanAsync(Guid userId, Guid trainerId, CreateWorkoutPlanRequest request,
        CancellationToken cancellationToken)
    {
        await using var transaction = await dbContext.Database.BeginTransactionAsync(cancellationToken);
        await advisorService.LockClientAsync(trainerId, userId, AdvisorType.Trainer, cancellationToken);
        var exerciseIds = request.Days.SelectMany(day => day.Exercises).Select(item => item.ExerciseId!.Value).Distinct().ToArray();
        // Catalog updates wait until the assignment commits; inactive exercises cannot be assigned.
        var exercises = await dbContext.Exercises
            .FromSqlInterpolated($"SELECT * FROM exercises WHERE id = ANY({exerciseIds}) FOR SHARE")
            .AsNoTracking().ToArrayAsync(cancellationToken);
        var activeIds = exercises.Where(exercise => exercise.IsActive).Select(exercise => exercise.Id).ToHashSet();
        var errors = new Dictionary<string, string[]>();
        for (var day = 0; day < request.Days.Length; day++)
            for (var item = 0; item < request.Days[day].Exercises.Length; item++)
                if (!activeIds.Contains(request.Days[day].Exercises[item].ExerciseId!.Value))
                    errors[$"days[{day}].exercises[{item}].exerciseId"] = ["Egzersiz bulunamadı veya aktif değil."];
        if (errors.Count != 0) throw new AssignmentException(400, "Validation failed", errors);
        var now = DateTime.UtcNow;
        await dbContext.WorkoutPlans.Where(plan => plan.UserId == userId && plan.IsActive)
            .ExecuteUpdateAsync(setters => setters.SetProperty(plan => plan.IsActive, false)
                .SetProperty(plan => plan.UpdatedAt, (DateTime?)now), cancellationToken);
        var plan = new WorkoutPlan { UserId = userId, TrainerId = trainerId, Name = request.Name.Trim(),
            Description = request.Description?.Trim(), StartDate = request.StartDate!.Value, EndDate = request.EndDate,
            Days = request.Days.Select(day => new WorkoutDay { Name = day.Name.Trim(), DayNumber = day.DayNumber!.Value,
                Weekday = Enum.Parse<Weekday>(day.Weekday), Description = day.Description?.Trim(),
                Exercises = day.Exercises.Select(item => new WorkoutExercise { ExerciseId = item.ExerciseId!.Value,
                    Order = item.Order!.Value, Sets = item.Sets, Reps = item.Reps, DurationSeconds = item.DurationSeconds,
                    RestSeconds = item.RestSeconds, WeightKg = item.WeightKg, Notes = item.Notes?.Trim() }).ToList() }).ToList() };
        dbContext.WorkoutPlans.Add(plan);
        await dbContext.SaveChangesAsync(cancellationToken);
        var response = (await GetWorkoutPlanAsync(plan.Id, trainerId, false, true, cancellationToken))!;
        await transaction.CommitAsync(cancellationToken);
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
