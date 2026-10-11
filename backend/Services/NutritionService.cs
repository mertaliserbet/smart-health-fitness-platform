using Microsoft.EntityFrameworkCore;
using SmartHealthFitness.Api.Contracts;
using SmartHealthFitness.Api.Data;

namespace SmartHealthFitness.Api.Services;

public sealed class NutritionService(AppDbContext dbContext)
{
    public Task<NutritionGoalResponse?> GetActiveNutritionGoalAsync(Guid userId, DateOnly date,
        CancellationToken cancellationToken) =>
        dbContext.NutritionGoals.AsNoTracking()
            .Where(goal => goal.UserId == userId && goal.IsActive && goal.StartDate <= date
                && (goal.EndDate == null || goal.EndDate >= date))
            .Select(goal => new NutritionGoalResponse(goal.Id, goal.DailyCalories, goal.ProteinGrams,
                goal.CarbohydrateGrams, goal.FatGrams, goal.WaterMl, goal.IsActive, goal.StartDate, goal.EndDate))
            .SingleOrDefaultAsync(cancellationToken);
}
