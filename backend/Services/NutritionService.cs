using Microsoft.EntityFrameworkCore;
using SmartHealthFitness.Api.Contracts;
using SmartHealthFitness.Api.Data;
using SmartHealthFitness.Api.Entities;

namespace SmartHealthFitness.Api.Services;

public sealed class NutritionService(AppDbContext dbContext, AdvisorService advisorService)
{
    public Task<NutritionGoalResponse[]> GetGoalsAsync(Guid userId, CancellationToken ct) =>
        dbContext.NutritionGoals.AsNoTracking().Where(goal => goal.UserId == userId)
            .OrderByDescending(goal => goal.IsActive).ThenByDescending(goal => goal.CreatedAt).ThenBy(goal => goal.Id)
            .Select(goal => new NutritionGoalResponse(goal.Id, goal.DailyCalories, goal.ProteinGrams,
                goal.CarbohydrateGrams, goal.FatGrams, goal.WaterMl, goal.IsActive, goal.StartDate, goal.EndDate))
            .ToArrayAsync(ct);

    public async Task<NutritionGoalResponse> CreateGoalAsync(Guid userId, Guid dietitianId,
        CreateNutritionGoalRequest request, CancellationToken ct)
    {
        await using var transaction = await dbContext.Database.BeginTransactionAsync(ct);
        await advisorService.LockClientAsync(userId, dietitianId, AdvisorType.Dietitian, ct);
        await dbContext.NutritionGoals.Where(goal => goal.UserId == userId && goal.IsActive)
            .ExecuteUpdateAsync(setters => setters.SetProperty(goal => goal.IsActive, false)
                .SetProperty(goal => goal.UpdatedAt, DateTime.UtcNow), ct);
        var goal = new NutritionGoal { UserId = userId, DietitianId = dietitianId,
            DailyCalories = request.DailyCalories, ProteinGrams = request.ProteinGrams,
            CarbohydrateGrams = request.CarbohydrateGrams, FatGrams = request.FatGrams, WaterMl = request.WaterMl,
            StartDate = request.StartDate, EndDate = request.EndDate };
        dbContext.NutritionGoals.Add(goal);
        await dbContext.SaveChangesAsync(ct);
        await transaction.CommitAsync(ct);
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
