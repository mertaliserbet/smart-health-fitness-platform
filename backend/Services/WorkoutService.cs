using Microsoft.EntityFrameworkCore;
using SmartHealthFitness.Api.Contracts;
using SmartHealthFitness.Api.Data;
using SmartHealthFitness.Api.Entities;

namespace SmartHealthFitness.Api.Services;

public sealed class WorkoutService(AppDbContext dbContext)
{
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
