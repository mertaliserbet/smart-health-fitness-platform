using Microsoft.EntityFrameworkCore;
using SmartHealthFitness.Api.Contracts;
using SmartHealthFitness.Api.Data;
using SmartHealthFitness.Api.Entities;

namespace SmartHealthFitness.Api.Services;

public sealed class AdvisorService(AppDbContext dbContext)
{
    private IQueryable<UserAdvisor> ActiveClients(Guid advisorId, AdvisorType? type) =>
        dbContext.UserAdvisors.AsNoTracking().Where(relation => relation.AdvisorId == advisorId
            && relation.Status == UserAdvisorStatus.Active && (type == null || relation.AdvisorType == type)
            && relation.User.IsActive && relation.User.UserRoles.Any(role => role.Role.Name == RoleNames.User)
            && relation.Advisor.IsActive && relation.Advisor.UserRoles.Any(role =>
                role.Role.Name == (relation.AdvisorType == AdvisorType.Trainer ? RoleNames.Trainer : RoleNames.Dietitian)));

    public Task<ClientSummaryResponse[]> GetClientsAsync(Guid advisorId, AdvisorType type, CancellationToken ct) =>
        ActiveClients(advisorId, type).OrderBy(relation => relation.User.LastName).ThenBy(relation => relation.UserId)
            .Select(relation => new ClientSummaryResponse(relation.UserId, relation.User.FirstName,
                relation.User.LastName, relation.Status, relation.StartDate)).ToArrayAsync(ct);

    public async Task RequireClientAsync(Guid userId, Guid advisorId, AdvisorType? type, CancellationToken ct)
    {
        if (!await ActiveClients(advisorId, type).AnyAsync(relation => relation.UserId == userId, ct))
            throw new AssignmentException(403, "Bu danışana erişiminiz bulunmuyor.");
    }

    // Caller owns the transaction. Serialize writes for a client, including active-plan/goal replacement.
    public async Task LockClientAsync(Guid userId, Guid advisorId, AdvisorType? type, CancellationToken ct)
    {
        await dbContext.Users.FromSqlInterpolated($"SELECT * FROM users WHERE id = {userId} FOR UPDATE")
            .AsNoTracking().ToArrayAsync(ct);
        // Keep the relationship stable until commit, even if an administrator ends it concurrently.
        await dbContext.UserAdvisors.FromSqlInterpolated($"SELECT * FROM user_advisors WHERE user_id = {userId} AND advisor_id = {advisorId} FOR SHARE")
            .AsNoTracking().ToArrayAsync(ct);
        await RequireClientAsync(userId, advisorId, type, ct);
    }

    public async Task<AdvisorNoteResponse> CreateNoteAsync(Guid userId, Guid advisorId,
        CreateAdvisorNoteRequest request, CancellationToken ct)
    {
        await using var transaction = await dbContext.Database.BeginTransactionAsync(ct);
        await LockClientAsync(userId, advisorId, null, ct);
        var note = new AdvisorNote { UserId = userId, AdvisorId = advisorId,
            Title = request.Title.Trim(), Content = request.Content.Trim() };
        dbContext.AdvisorNotes.Add(note);
        await dbContext.SaveChangesAsync(ct);
        await transaction.CommitAsync(ct);
        return new(note.Id, userId, advisorId, note.Title, note.Content, note.CreatedAt, note.UpdatedAt);
    }

    public async Task<UserTaskResponse> CreateTaskAsync(Guid userId, Guid advisorId,
        CreateUserTaskRequest request, CancellationToken ct)
    {
        await using var transaction = await dbContext.Database.BeginTransactionAsync(ct);
        await LockClientAsync(userId, advisorId, null, ct);
        var task = new UserTask { UserId = userId, AdvisorId = advisorId, Title = request.Title.Trim(),
            Description = request.Description?.Trim(), DueDate = request.DueDate };
        dbContext.UserTasks.Add(task);
        await dbContext.SaveChangesAsync(ct);
        await transaction.CommitAsync(ct);
        return TaskResponse(task);
    }

    public async Task<UserTaskResponse> UpdateTaskAsync(Guid taskId, Guid currentUserId,
        bool isUser, bool isAdvisor, UpdateTaskStatusRequest request, CancellationToken ct)
    {
        await using var transaction = await dbContext.Database.BeginTransactionAsync(ct);
        var task = (await dbContext.UserTasks.FromSqlInterpolated($"SELECT * FROM user_tasks WHERE id = {taskId} FOR UPDATE")
            .ToArrayAsync(ct)).SingleOrDefault();
        var owner = task is not null && isUser && task.UserId == currentUserId;
        var creator = task is not null && isAdvisor && task.AdvisorId == currentUserId;
        if (task is null || (!owner && !creator)) throw new AssignmentException(404, "Görev bulunamadı.");
        if (!owner) await LockClientAsync(task.UserId, currentUserId, null, ct);
        var status = Enum.Parse<UserTaskStatus>(request.Status);
        if (owner && status != UserTaskStatus.Completed)
            throw new AssignmentException(403, "Kullanıcı yalnız kendi görevini tamamlayabilir.");
        if (task.Status == status) return TaskResponse(task);
        if (task.Status is UserTaskStatus.Completed or UserTaskStatus.Cancelled)
            throw new AssignmentException(409, "Tamamlanan veya iptal edilen görevin durumu değiştirilemez.");
        task.Status = status;
        task.UpdatedAt = DateTime.UtcNow;
        task.CompletedAt = status == UserTaskStatus.Completed ? task.UpdatedAt : null;
        await dbContext.SaveChangesAsync(ct);
        // Return PostgreSQL's stored timestamp precision, also on the first completion response.
        await dbContext.Entry(task).ReloadAsync(ct);
        await transaction.CommitAsync(ct);
        return TaskResponse(task);
    }

    private static UserTaskResponse TaskResponse(UserTask task) => new(task.Id, task.UserId, task.AdvisorId,
        task.Title, task.Description, task.DueDate, task.Status, task.CompletedAt, task.CreatedAt, task.UpdatedAt);

    public Task<UserAdvisorResponse[]> GetUserAdvisorsAsync(Guid userId, CancellationToken cancellationToken) =>
        dbContext.UserAdvisors.AsNoTracking()
            .Where(relation => relation.UserId == userId && relation.Status == UserAdvisorStatus.Active
                && relation.Advisor.IsActive && relation.Advisor.UserRoles.Any(role =>
                    role.Role.Name == (relation.AdvisorType == AdvisorType.Trainer ? RoleNames.Trainer : RoleNames.Dietitian)))
            .OrderBy(relation => relation.AdvisorType == AdvisorType.Trainer ? 0 : 1).ThenBy(relation => relation.Advisor.LastName)
            .ThenBy(relation => relation.Id)
            .Select(relation => new UserAdvisorResponse(relation.Id, relation.AdvisorId, relation.AdvisorType,
                relation.Advisor.FirstName, relation.Advisor.LastName,
                dbContext.AdvisorProfiles.Where(profile => profile.UserId == relation.AdvisorId
                    && profile.AdvisorType == relation.AdvisorType && profile.IsActive).Select(profile => profile.Title).FirstOrDefault(),
                dbContext.AdvisorProfiles.Where(profile => profile.UserId == relation.AdvisorId
                    && profile.AdvisorType == relation.AdvisorType && profile.IsActive).Select(profile => profile.Specialization).FirstOrDefault(),
                relation.Status, relation.StartDate, relation.EndDate))
            .ToArrayAsync(cancellationToken);

    public Task<AdvisorNoteResponse[]> GetAdvisorNotesAsync(Guid userId, CancellationToken cancellationToken) =>
        dbContext.AdvisorNotes.AsNoTracking().Where(note => note.UserId == userId)
            .OrderByDescending(note => note.CreatedAt).ThenBy(note => note.Id)
            .Select(note => new AdvisorNoteResponse(note.Id, note.UserId, note.AdvisorId, note.Title,
                note.Content, note.CreatedAt, note.UpdatedAt)).ToArrayAsync(cancellationToken);

    public Task<UserTaskResponse[]> GetUserTasksAsync(Guid userId, UserTaskStatus? status,
        CancellationToken cancellationToken) =>
        dbContext.UserTasks.AsNoTracking().Where(task => task.UserId == userId
                && (status == null || task.Status == status))
            .OrderByDescending(task => task.CreatedAt).ThenBy(task => task.Id)
            .Select(task => new UserTaskResponse(task.Id, task.UserId, task.AdvisorId, task.Title,
                task.Description, task.DueDate, task.Status, task.CompletedAt, task.CreatedAt, task.UpdatedAt))
            .ToArrayAsync(cancellationToken);
}
