using Microsoft.EntityFrameworkCore;
using SmartHealthFitness.Api.Contracts;
using SmartHealthFitness.Api.Data;
using SmartHealthFitness.Api.Entities;

namespace SmartHealthFitness.Api.Services;

public sealed class NutritionService(AppDbContext dbContext, AdvisorService advisorService)
{
    public async Task<NutritionRecordResponse> CreateRecordAsync(Guid userId, CreateNutritionRecordRequest request,
        CancellationToken ct)
    {
        var record = new NutritionRecord { UserId = userId, MealType = Enum.Parse<MealType>(request.MealType),
            Name = request.Name.Trim(), Calories = request.Calories!.Value,
            ProteinGrams = request.ProteinGrams!.Value, CarbohydrateGrams = request.CarbohydrateGrams!.Value,
            FatGrams = request.FatGrams!.Value, PortionDescription = request.PortionDescription?.Trim(),
            SourceType = NutritionSourceType.Manual, ConsumedAt = request.ConsumedAt!.Value.UtcDateTime };
        dbContext.NutritionRecords.Add(record);
        await dbContext.SaveChangesAsync(ct);
        await dbContext.Entry(record).ReloadAsync(ct);
        return NutritionRecordResponse.FromRecord(record);
    }

    public async Task<NutritionRecordResponse[]> GetRecordsAsync(Guid userId, DateTime? from, DateTime? to,
        MealType? mealType, CancellationToken ct) =>
        (await RecordQuery(userId, from, to).Where(record => mealType == null || record.MealType == mealType)
            .OrderByDescending(record => record.ConsumedAt).ThenByDescending(record => record.CreatedAt).ThenBy(record => record.Id)
            .ToArrayAsync(ct)).Select(NutritionRecordResponse.FromRecord).ToArray();

    private IQueryable<NutritionRecord> RecordQuery(Guid userId, DateTime? from, DateTime? to) =>
        dbContext.NutritionRecords.AsNoTracking().Where(record => record.UserId == userId
            && (from == null || record.ConsumedAt >= from) && (to == null || record.ConsumedAt < to));

    public async Task<NutritionDailySummaryResponse> GetDailySummaryAsync(Guid userId, DateOnly date,
        DateTime from, DateTime to, CancellationToken ct)
    {
        // Records and the assigned target must describe the same database snapshot.
        await using var transaction = await dbContext.Database.BeginTransactionAsync(System.Data.IsolationLevel.RepeatableRead, ct);
        var totals = await RecordQuery(userId, from, to).GroupBy(record => 1)
            .Select(group => new { Count = group.Count(), Calories = group.Sum(record => record.Calories),
                Protein = group.Sum(record => record.ProteinGrams), Carbohydrates = group.Sum(record => record.CarbohydrateGrams),
                Fat = group.Sum(record => record.FatGrams) }).SingleOrDefaultAsync(ct);
        var goal = await GetActiveNutritionGoalAsync(userId, date, ct);
        await transaction.CommitAsync(ct);
        return new(date, totals?.Count ?? 0, totals?.Calories ?? 0, totals?.Protein ?? 0,
            totals?.Carbohydrates ?? 0, totals?.Fat ?? 0, goal);
    }

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
