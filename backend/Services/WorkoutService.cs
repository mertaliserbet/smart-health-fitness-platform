using Microsoft.EntityFrameworkCore;
using SmartHealthFitness.Api.Contracts;
using SmartHealthFitness.Api.Data;
using SmartHealthFitness.Api.Entities;

namespace SmartHealthFitness.Api.Services;

public sealed class WorkoutService(AppDbContext dbContext, AdvisorService advisorService)
{
    public async Task<WorkoutPlanResponse> UpdatePlanAsync(Guid planId, Guid trainerId,
        UpdateWorkoutPlanRequest request, CancellationToken ct)
    {
        await using var transaction = await dbContext.Database.BeginTransactionAsync(ct);
        // Check creator before taking a client lock; unrelated IDs remain indistinguishable from missing IDs.
        var userId = await dbContext.WorkoutPlans.AsNoTracking()
            .Where(plan => plan.Id == planId && plan.TrainerId == trainerId)
            .Select(plan => (Guid?)plan.UserId).SingleOrDefaultAsync(ct);
        if (userId is null) throw AssignmentException.NotFound("Program bulunamadı.");
        await advisorService.LockClientAsync(trainerId, userId.Value, AdvisorType.Trainer, ct);
        var plan = await dbContext.WorkoutPlans.Include(value => value.Days).ThenInclude(day => day.Exercises)
            .AsSplitQuery().SingleAsync(value => value.Id == planId, ct);
        if (!plan.IsActive) throw AssignmentException.Conflict("Geçmiş program düzenlenemez. Yeni bir program ata.");
        if (await dbContext.WorkoutSessions.AnyAsync(session => session.WorkoutPlanId == planId, ct))
            throw AssignmentException.Conflict("Bu programla antrenman başlatılmış. Geçmişi korumak için yeni bir program ata.");
        if (request.ExpectedUpdatedAt?.UtcDateTime != plan.UpdatedAt)
            throw AssignmentException.Conflict("Program başka bir ekranda değişti. Güncel programı açıp yeniden düzenle.");

        var errors = new Dictionary<string, string[]>();
        var daysById = plan.Days.ToDictionary(day => day.Id);
        var seenDays = new HashSet<Guid>();
        var seenItems = new HashSet<Guid>();
        var exerciseIds = request.Days.SelectMany(day => day.Exercises).Select(item => item.ExerciseId!.Value)
            .Distinct().Order().ToArray();
        var catalog = await dbContext.Exercises
            .FromSqlInterpolated($"SELECT * FROM exercises WHERE id = ANY({exerciseIds}) ORDER BY id FOR SHARE")
            .AsNoTracking().ToDictionaryAsync(exercise => exercise.Id, ct);
        for (var dayIndex = 0; dayIndex < request.Days.Length; dayIndex++)
        {
            var day = request.Days[dayIndex];
            var path = $"days[{dayIndex}]";
            WorkoutDay? existingDay = null;
            if (day.Id is not null && (!daysById.TryGetValue(day.Id.Value, out existingDay) || !seenDays.Add(day.Id.Value)))
                errors[path + ".id"] = ["Bu programa ait benzersiz bir gün seçin."];
            for (var itemIndex = 0; itemIndex < day.Exercises.Length; itemIndex++)
            {
                var item = day.Exercises[itemIndex];
                var itemPath = path + $".exercises[{itemIndex}]";
                var existingItem = existingDay?.Exercises.SingleOrDefault(value => value.Id == item.Id);
                if (item.Id is not null && (existingItem is null || !seenItems.Add(item.Id.Value)
                    || existingItem.ExerciseId != item.ExerciseId))
                    errors[itemPath + ".id"] = ["Bu güne ait egzersiz kimliğini koruyun; farklı egzersizi yeni satır olarak ekleyin."];
                // Retained inactive exercises can keep their prescription; only new assignments require an active catalog entry.
                if (!catalog.TryGetValue(item.ExerciseId!.Value, out var exercise)
                    || (!exercise.IsActive && (existingItem is null || existingItem.ExerciseId != item.ExerciseId)))
                    errors[itemPath + ".exerciseId"] = ["Egzersiz bulunamadı veya aktif değil."];
            }
        }
        if (errors.Count != 0) throw new AssignmentException(400, "Validation failed", errors);

        // Replace rows atomically with the same retained IDs. This also handles weekday/order swaps under unique indexes.
        dbContext.WorkoutDays.RemoveRange(plan.Days);
        await dbContext.SaveChangesAsync(ct);
        plan.Name = request.Name.Trim();
        plan.Description = request.Description?.Trim();
        plan.StartDate = request.StartDate!.Value;
        plan.EndDate = request.EndDate;
        var now = DateTime.UtcNow;
        now = new DateTime(now.Ticks - now.Ticks % 10, DateTimeKind.Utc); // PostgreSQL microseconds.
        plan.UpdatedAt = plan.UpdatedAt >= now ? plan.UpdatedAt.Value.AddTicks(10) : now;
        plan.Days = request.Days.Select(day => new WorkoutDay { Id = day.Id ?? Guid.NewGuid(),
            WorkoutPlanId = plan.Id, Name = day.Name.Trim(), DayNumber = day.DayNumber!.Value,
            Weekday = Enum.Parse<Weekday>(day.Weekday), Description = day.Description?.Trim(),
            Exercises = day.Exercises.Select(item => new WorkoutExercise { Id = item.Id ?? Guid.NewGuid(),
                ExerciseId = item.ExerciseId!.Value, Order = item.Order!.Value, Sets = item.Sets, Reps = item.Reps,
                DurationSeconds = item.DurationSeconds, RestSeconds = item.RestSeconds,
                WeightKg = item.WeightKg, Notes = item.Notes?.Trim() }).ToList() }).ToList();
        dbContext.WorkoutDays.AddRange(plan.Days);
        await dbContext.SaveChangesAsync(ct);
        var response = (await GetWorkoutPlanAsync(plan.Id, trainerId, false, true, ct))!;
        await transaction.CommitAsync(ct);
        return response;
    }

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
                        .ToArray())).ToArray(), plan.UpdatedAt,
            await dbContext.WorkoutSessions.AnyAsync(session => session.WorkoutPlanId == plan.Id, cancellationToken));
    }
}
