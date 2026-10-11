using Microsoft.EntityFrameworkCore;
using SmartHealthFitness.Api.Contracts;
using SmartHealthFitness.Api.Data;
using SmartHealthFitness.Api.Entities;

namespace SmartHealthFitness.Api.Services;

public sealed class NutritionService(AppDbContext dbContext, AdvisorService advisorService)
{
    public Task<NutritionGoalResponse[]> GetNutritionGoalsAsync(Guid userId, CancellationToken cancellationToken) =>
        dbContext.NutritionGoals.AsNoTracking().Where(goal => goal.UserId == userId)
            .OrderByDescending(goal => goal.IsActive).ThenByDescending(goal => goal.CreatedAt).ThenBy(goal => goal.Id)
            .Select(goal => new NutritionGoalResponse(goal.Id, goal.DailyCalories, goal.ProteinGrams,
                goal.CarbohydrateGrams, goal.FatGrams, goal.WaterMl, goal.IsActive, goal.StartDate, goal.EndDate))
            .ToArrayAsync(cancellationToken);

    public async Task<NutritionGoalResponse> CreateNutritionGoalAsync(Guid userId, Guid dietitianId,
        CreateNutritionGoalRequest request, CancellationToken cancellationToken)
    {
        await using var transaction = await dbContext.Database.BeginTransactionAsync(cancellationToken);
        await advisorService.LockClientAsync(dietitianId, userId, AdvisorType.Dietitian, cancellationToken);
        var now = DateTime.UtcNow;
        await dbContext.NutritionGoals.Where(goal => goal.UserId == userId && goal.IsActive)
            .ExecuteUpdateAsync(setters => setters.SetProperty(goal => goal.IsActive, false)
                .SetProperty(goal => goal.UpdatedAt, (DateTime?)now), cancellationToken);
        var goal = new NutritionGoal { UserId = userId, DietitianId = dietitianId,
            DailyCalories = request.DailyCalories!.Value, ProteinGrams = request.ProteinGrams!.Value,
            CarbohydrateGrams = request.CarbohydrateGrams!.Value, FatGrams = request.FatGrams!.Value,
            WaterMl = request.WaterMl!.Value, StartDate = request.StartDate!.Value, EndDate = request.EndDate };
        dbContext.NutritionGoals.Add(goal);
        await dbContext.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return new(goal.Id, goal.DailyCalories, goal.ProteinGrams, goal.CarbohydrateGrams,
            goal.FatGrams, goal.WaterMl, goal.IsActive, goal.StartDate, goal.EndDate);
    }

    public Task<NutritionGoalResponse?> GetActiveNutritionGoalAsync(Guid userId, DateOnly date,
        CancellationToken cancellationToken) =>
        dbContext.NutritionGoals.AsNoTracking()
            .Where(goal => goal.UserId == userId && goal.IsActive && goal.StartDate <= date
                && (goal.EndDate == null || goal.EndDate >= date))
            .Select(goal => new NutritionGoalResponse(goal.Id, goal.DailyCalories, goal.ProteinGrams,
                goal.CarbohydrateGrams, goal.FatGrams, goal.WaterMl, goal.IsActive, goal.StartDate, goal.EndDate))
            .SingleOrDefaultAsync(cancellationToken);
}
