using Microsoft.EntityFrameworkCore;
using SmartHealthFitness.Api.Contracts;
using SmartHealthFitness.Api.Data;
using SmartHealthFitness.Api.Entities;

namespace SmartHealthFitness.Api.Services;

public sealed class WorkoutSessionService(AppDbContext db, AdvisorService advisors)
{
    public async Task<(WorkoutSessionResponse Session, bool Created)> StartAsync(Guid userId,
        StartWorkoutSessionRequest request, CancellationToken ct)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        await LockUserAsync(userId, ct);
        var existing = await Details(db.WorkoutSessions.Where(session => session.UserId == userId
            && session.Status == WorkoutSessionStatus.InProgress)).SingleOrDefaultAsync(ct);
        if (existing is not null)
        {
            if (existing.WorkoutPlanId != request.WorkoutPlanId || existing.WorkoutDayId != request.WorkoutDayId)
                throw AssignmentException.Conflict("Önce açık antrenmanı tamamla veya iptal et.");
            await transaction.CommitAsync(ct);
            return (ToResponse(existing), false);
        }
        var day = await db.WorkoutDays.Include(day => day.WorkoutPlan)
            .Include(day => day.Exercises).ThenInclude(item => item.Exercise).AsSplitQuery()
            .SingleOrDefaultAsync(day => day.Id == request.WorkoutDayId
                && day.WorkoutPlanId == request.WorkoutPlanId && day.WorkoutPlan.UserId == userId, ct);
        if (day is null) throw AssignmentException.NotFound("Antrenman günü bulunamadı.");
        var today = DateOnly.FromDateTime(DateTime.UtcNow);
        if (!day.WorkoutPlan.IsActive || day.WorkoutPlan.StartDate > today || day.WorkoutPlan.EndDate < today)
            throw AssignmentException.Conflict("Bu program şu anda aktif değil. Güncel programı aç.");
        var session = new WorkoutSession { UserId = userId, StartedAt = UtcNow(), WorkoutPlanId = day.WorkoutPlanId,
            WorkoutDayId = day.Id, WorkoutPlan = day.WorkoutPlan, WorkoutDay = day };
        db.WorkoutSessions.Add(session);
        await db.SaveChangesAsync(ct);
        await transaction.CommitAsync(ct);
        return (ToResponse(session), true);
    }

    public async Task<WorkoutLogResponse> SaveLogAsync(Guid userId, Guid sessionId, Guid workoutExerciseId,
        SaveWorkoutLogRequest request, CancellationToken ct)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        await LockUserAsync(userId, ct);
        var session = await OwnedSessionAsync(userId, sessionId, ct);
        if (session.Status != WorkoutSessionStatus.InProgress)
            throw AssignmentException.Conflict("Bitmiş antrenmanın kayıtları değiştirilemez.");
        var item = session.WorkoutDay.Exercises.SingleOrDefault(item => item.Id == workoutExerciseId)
            ?? throw AssignmentException.NotFound("Bu antrenmana ait egzersiz bulunamadı.");
        if (item.DurationSeconds is not null)
        {
            if (request.CompletedSets is not null || request.CompletedReps is not null)
                throw AssignmentException.Invalid("durationSeconds", "Süre hedefli egzersiz için set/tekrar kaydedilemez.");
            if (request.IsCompleted == true && request.DurationSeconds is not > 0)
                throw AssignmentException.Invalid("durationSeconds", "Tamamlanan egzersizin süresini girin.");
        }
        else
        {
            if (request.DurationSeconds is not null)
                throw AssignmentException.Invalid("durationSeconds", "Set/tekrar hedefli egzersiz için süre kaydedilemez.");
            if (request.IsCompleted == true && (request.CompletedSets is not > 0 || request.CompletedReps is not > 0))
                throw AssignmentException.Invalid("completedSets", "Tamamlanan egzersizin set ve tekrarlarını girin.");
        }
        var log = session.Logs.SingleOrDefault(log => log.WorkoutExerciseId == workoutExerciseId);
        if (log is null)
        {
            log = new WorkoutLog { WorkoutSessionId = session.Id, WorkoutExerciseId = workoutExerciseId, CreatedAt = UtcNow() };
            session.Logs.Add(log);
            db.WorkoutLogs.Add(log);
        }
        log.CompletedSets = request.CompletedSets;
        log.CompletedReps = request.CompletedReps;
        log.DurationSeconds = request.DurationSeconds;
        log.WeightKg = request.WeightKg;
        log.IsCompleted = request.IsCompleted!.Value;
        log.Notes = request.Notes?.Trim();
        await db.SaveChangesAsync(ct);
        await transaction.CommitAsync(ct);
        return ToLogResponse(log);
    }

    public async Task<WorkoutSessionResponse> FinishAsync(Guid userId, Guid sessionId,
        WorkoutSessionStatus status, CancellationToken ct)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        await LockUserAsync(userId, ct);
        var session = await OwnedSessionAsync(userId, sessionId, ct);
        if (session.Status != status)
        {
            if (session.Status != WorkoutSessionStatus.InProgress)
                throw AssignmentException.Conflict("Antrenman zaten bitmiş; durumu değiştirilemez.");
            session.Status = status;
            if (status == WorkoutSessionStatus.Completed)
            {
                var now = UtcNow();
                session.CompletedAt = now < session.StartedAt ? session.StartedAt : now;
            }
            await db.SaveChangesAsync(ct);
        }
        await transaction.CommitAsync(ct);
        return ToResponse(session);
    }

    public async Task<PagedWorkoutSessionsResponse> GetHistoryAsync(Guid userId, WorkoutSessionQuery filter,
        CancellationToken ct)
    {
        var query = db.WorkoutSessions.AsNoTracking().Where(session => session.UserId == userId);
        if (filter.Status is not null)
        {
            var status = Enum.Parse<WorkoutSessionStatus>(filter.Status);
            query = query.Where(session => session.Status == status);
        }
        var total = await query.CountAsync(ct);
        var items = await query.OrderByDescending(session => session.StartedAt).ThenByDescending(session => session.Id)
            .Skip((filter.Page - 1) * filter.PageSize).Take(filter.PageSize)
            .Select(session => new WorkoutSessionSummaryResponse(session.Id, session.UserId, session.WorkoutPlanId,
                session.WorkoutDayId, session.WorkoutPlan.Name, session.WorkoutDay.Name, session.StartedAt,
                session.CompletedAt, session.Status, session.Logs.Count(log => log.IsCompleted), session.WorkoutDay.Exercises.Count))
            .ToArrayAsync(ct);
        return new(items, filter.Page, filter.PageSize, total, (int)Math.Ceiling((double)total / filter.PageSize));
    }

    public async Task<PagedWorkoutSessionsResponse> GetClientHistoryAsync(Guid trainerId, Guid userId,
        WorkoutSessionQuery query, CancellationToken ct)
    {
        await advisors.RequireClientAsync(trainerId, userId, AdvisorType.Trainer, ct);
        return await GetHistoryAsync(userId, query, ct);
    }

    public async Task<WorkoutSessionResponse?> GetAsync(Guid sessionId, Guid readerId,
        bool canReadOwn, bool isTrainer, CancellationToken ct)
    {
        // Authorize before materializing exercise/log details; unrelated session IDs return 404.
        var session = await Details(db.WorkoutSessions.AsNoTracking().Where(session => session.Id == sessionId
            && ((canReadOwn && session.UserId == readerId) || (isTrainer && db.UserAdvisors.Any(relation =>
                relation.UserId == session.UserId && relation.AdvisorId == readerId
                && relation.AdvisorType == AdvisorType.Trainer && relation.Status == UserAdvisorStatus.Active
                && relation.User.IsActive && relation.User.UserRoles.Any(role => role.Role.Name == RoleNames.User)
                && relation.Advisor.IsActive && relation.Advisor.UserRoles.Any(role => role.Role.Name == RoleNames.Trainer))))))
            .SingleOrDefaultAsync(ct);
        return session is null ? null : ToResponse(session);
    }

    private async Task LockUserAsync(Guid userId, CancellationToken ct) =>
        // Same lock as assignment replacement and plan editing, always acquired before session/log writes.
        _ = await db.Users.FromSqlInterpolated($"SELECT * FROM users WHERE id = {userId} FOR UPDATE").SingleAsync(ct);

    private async Task<WorkoutSession> OwnedSessionAsync(Guid userId, Guid sessionId, CancellationToken ct) =>
        await Details(db.WorkoutSessions.Where(session => session.Id == sessionId && session.UserId == userId))
            .SingleOrDefaultAsync(ct) ?? throw AssignmentException.NotFound("Antrenman bulunamadı.");

    private static IQueryable<WorkoutSession> Details(IQueryable<WorkoutSession> query) => query
        .Include(session => session.WorkoutPlan).Include(session => session.Logs)
        .Include(session => session.WorkoutDay).ThenInclude(day => day.Exercises).ThenInclude(item => item.Exercise)
        .AsSplitQuery();

    private static WorkoutLogResponse ToLogResponse(WorkoutLog log) => new(log.Id, log.WorkoutExerciseId,
        log.CompletedSets, log.CompletedReps, log.WeightKg, log.DurationSeconds, log.IsCompleted, log.Notes, log.CreatedAt);

    private static DateTime UtcNow()
    {
        var now = DateTime.UtcNow;
        return new DateTime(now.Ticks - now.Ticks % 10, DateTimeKind.Utc);
    }

    private static WorkoutSessionResponse ToResponse(WorkoutSession session) => new(session.Id, session.UserId,
        session.WorkoutPlanId, session.WorkoutDayId, session.WorkoutPlan.Name, session.StartedAt, session.CompletedAt,
        session.Status, new WorkoutDayResponse(session.WorkoutDayId, session.WorkoutDay.Name, session.WorkoutDay.DayNumber,
            session.WorkoutDay.Weekday, session.WorkoutDay.Description, session.WorkoutDay.Exercises.OrderBy(item => item.Order)
                .ThenBy(item => item.Id).Select(item => new WorkoutExerciseResponse(item.Id, item.ExerciseId,
                    item.Exercise.Name, item.Order, item.Sets, item.Reps, item.DurationSeconds, item.RestSeconds,
                    item.WeightKg, item.Notes)).ToArray()),
        session.Logs.OrderBy(log => log.CreatedAt).ThenBy(log => log.Id).Select(ToLogResponse).ToArray());
}
