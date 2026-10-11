using Microsoft.EntityFrameworkCore;
using Npgsql;
using SmartHealthFitness.Api.Contracts;
using SmartHealthFitness.Api.Data;
using SmartHealthFitness.Api.Entities;

namespace SmartHealthFitness.Api.Services;

public sealed class AdvisorService(AppDbContext dbContext)
{
    public Task<ClientSummaryResponse[]> GetClientsAsync(Guid advisorId, AdvisorType type,
        CancellationToken cancellationToken) =>
        ClientRelations(advisorId, type).OrderBy(relation => relation.User.LastName)
            .ThenBy(relation => relation.User.FirstName).ThenBy(relation => relation.UserId)
            .Select(relation => new ClientSummaryResponse(relation.UserId, relation.User.FirstName,
                relation.User.LastName, relation.Status, relation.StartDate)).ToArrayAsync(cancellationToken);

    private IQueryable<UserAdvisor> ClientRelations(Guid advisorId, AdvisorType? type) =>
        dbContext.UserAdvisors.AsNoTracking().Where(relation => relation.AdvisorId == advisorId
            && (type == null || relation.AdvisorType == type) && relation.Status == UserAdvisorStatus.Active
            && relation.User.IsActive && relation.User.UserRoles.Any(role => role.Role.Name == RoleNames.User)
            && relation.Advisor.IsActive && relation.Advisor.UserRoles.Any(role =>
                role.Role.Name == (relation.AdvisorType == AdvisorType.Trainer ? RoleNames.Trainer : RoleNames.Dietitian)));

    public async Task RequireClientAsync(Guid advisorId, Guid userId, AdvisorType? type,
        CancellationToken cancellationToken)
    {
        if (!await ClientRelations(advisorId, type).AnyAsync(relation => relation.UserId == userId, cancellationToken))
            throw new AssignmentException(403, "Bu danışana erişiminiz bulunmuyor.");
    }

    // Writers take this lock in their transaction before checking the relationship.
    // Assignment replacement and Admin termination therefore serialize per client.
    public async Task LockClientAsync(Guid advisorId, Guid userId, AdvisorType? type,
        CancellationToken cancellationToken)
    {
        await LockUserAsync(userId, cancellationToken);
        await RequireClientAsync(advisorId, userId, type, cancellationToken);
    }

    private async Task<User> LockUserAsync(Guid userId, CancellationToken cancellationToken) =>
        await dbContext.Users.FromSqlInterpolated($"SELECT * FROM users WHERE id = {userId} FOR UPDATE")
            .SingleOrDefaultAsync(cancellationToken) ?? throw AssignmentException.NotFound();

    public async Task<UserProfileResponse> GetClientProfileAsync(Guid userId, Guid advisorId,
        bool isAdmin, bool isTrainer, bool isDietitian, CancellationToken cancellationToken)
    {
        var assigned = (isTrainer && await ClientRelations(advisorId, AdvisorType.Trainer)
            .AnyAsync(relation => relation.UserId == userId, cancellationToken))
            || (isDietitian && await ClientRelations(advisorId, AdvisorType.Dietitian)
                .AnyAsync(relation => relation.UserId == userId, cancellationToken));
        if (!isAdmin && !assigned) throw new AssignmentException(403, "Bu danışana erişiminiz bulunmuyor.");
        var query = dbContext.Users.AsNoTracking().Where(user => user.Id == userId);
        // Admin account management does not expose birth date, gender or height.
        var response = await query.Select(user => new UserProfileResponse(user.Id, user.FirstName,
            user.LastName, user.Email, user.PhoneNumber, assigned ? user.BirthDate : null,
            assigned ? user.Gender : null, assigned ? user.HeightCm : null,
            user.UserRoles.Select(role => role.Role.Name).OrderBy(name => name).ToArray()))
            .SingleOrDefaultAsync(cancellationToken);
        return response ?? throw AssignmentException.NotFound("Kullanıcı bulunamadı.");
    }

    public async Task<PagedUsersResponse> GetUsersAsync(int page, int pageSize, string? role,
        string? search, CancellationToken cancellationToken)
    {
        if (role is not null && role is not (RoleNames.User or RoleNames.Trainer or RoleNames.Dietitian or RoleNames.Admin))
            throw AssignmentException.Invalid("role", "Geçerli bir rol seçin.");
        var query = dbContext.Users.AsNoTracking();
        if (role is not null) query = query.Where(user => user.UserRoles.Any(item => item.Role.Name == role));
        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim().ToLower();
            query = query.Where(user => (user.FirstName + " " + user.LastName).ToLower().Contains(term)
                || user.Email.Contains(term));
        }
        var total = await query.CountAsync(cancellationToken);
        var items = await query.OrderBy(user => user.LastName).ThenBy(user => user.FirstName).ThenBy(user => user.Id)
            .Skip((page - 1) * pageSize).Take(pageSize)
            .Select(user => new RegisterResponse(user.Id, user.FirstName, user.LastName, user.Email,
                user.UserRoles.Select(item => item.Role.Name).OrderBy(name => name).ToArray())).ToArrayAsync(cancellationToken);
        return new(items, page, pageSize, total, (int)Math.Ceiling((double)total / pageSize));
    }

    public Task<UserAdvisorManagementResponse[]> GetRelationsAsync(Guid userId, CancellationToken cancellationToken) =>
        dbContext.UserAdvisors.AsNoTracking().Where(relation => relation.UserId == userId)
            .OrderByDescending(relation => relation.CreatedAt).ThenBy(relation => relation.Id)
            .Select(relation => new UserAdvisorManagementResponse(relation.Id, relation.UserId, relation.AdvisorId,
                relation.AdvisorType, relation.Status, relation.StartDate, relation.EndDate)).ToArrayAsync(cancellationToken);

    public async Task<UserAdvisorManagementResponse> CreateRelationAsync(CreateUserAdvisorRequest request,
        CancellationToken cancellationToken)
    {
        await using var transaction = await dbContext.Database.BeginTransactionAsync(cancellationToken);
        var user = await LockUserAsync(request.UserId!.Value, cancellationToken);
        if (!user.IsActive || !await dbContext.UserRoles.AnyAsync(role => role.UserId == user.Id
            && role.Role.Name == RoleNames.User, cancellationToken))
            throw AssignmentException.Invalid("userId", "Aktif User hesabı seçin.");
        var type = Enum.Parse<AdvisorType>(request.AdvisorType);
        var roleName = type == AdvisorType.Trainer ? RoleNames.Trainer : RoleNames.Dietitian;
        if (!await dbContext.Users.AnyAsync(advisor => advisor.Id == request.AdvisorId && advisor.IsActive
            && advisor.UserRoles.Any(role => role.Role.Name == roleName), cancellationToken))
            throw AssignmentException.Invalid("advisorId", "Seçilen danışman aktif olmalı ve ilgili role sahip olmalıdır.");
        if (await dbContext.UserAdvisors.AnyAsync(relation => relation.UserId == user.Id
            && relation.AdvisorId == request.AdvisorId && relation.Status == UserAdvisorStatus.Active, cancellationToken))
            throw AssignmentException.Conflict("Bu kullanıcı-danışman ilişkisi zaten aktif.");
        var relation = new UserAdvisor { UserId = user.Id, AdvisorId = request.AdvisorId!.Value,
            AdvisorType = type, StartDate = request.StartDate!.Value };
        dbContext.UserAdvisors.Add(relation);
        try { await dbContext.SaveChangesAsync(cancellationToken); }
        catch (DbUpdateException exception) when (exception.InnerException is PostgresException
            { SqlState: PostgresErrorCodes.UniqueViolation, ConstraintName: "ux_user_advisors_active_user_advisor" })
        {
            throw AssignmentException.Conflict("Bu kullanıcı-danışman ilişkisi zaten aktif.");
        }
        await transaction.CommitAsync(cancellationToken);
        return UserAdvisorManagementResponse.FromRelation(relation);
    }

    public async Task<UserAdvisorManagementResponse> EndRelationAsync(Guid relationId, UpdateUserAdvisorRequest request,
        CancellationToken cancellationToken)
    {
        await using var transaction = await dbContext.Database.BeginTransactionAsync(cancellationToken);
        var userId = await dbContext.UserAdvisors.AsNoTracking().Where(relation => relation.Id == relationId)
            .Select(relation => (Guid?)relation.UserId).SingleOrDefaultAsync(cancellationToken);
        if (userId is null) throw AssignmentException.NotFound("Danışman ilişkisi bulunamadı.");
        await LockUserAsync(userId.Value, cancellationToken);
        var relation = await dbContext.UserAdvisors.SingleAsync(relation => relation.Id == relationId, cancellationToken);
        var status = Enum.Parse<UserAdvisorStatus>(request.Status);
        if (request.EndDate < relation.StartDate || request.EndDate > DateOnly.FromDateTime(DateTime.UtcNow))
            throw AssignmentException.Invalid("endDate", "Bitiş tarihi başlangıçtan önce veya gelecekte olamaz.");
        if (relation.Status != UserAdvisorStatus.Active && (relation.Status != status || relation.EndDate != request.EndDate))
            throw AssignmentException.Conflict("Sonlandırılmış ilişki tekrar değiştirilemez.");
        relation.Status = status;
        relation.EndDate = request.EndDate;
        await dbContext.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return UserAdvisorManagementResponse.FromRelation(relation);
    }

    public async Task<AdvisorNoteResponse> CreateNoteAsync(Guid userId, Guid advisorId,
        CreateAdvisorNoteRequest request, CancellationToken ct)
    {
        await using var transaction = await dbContext.Database.BeginTransactionAsync(ct);
        await LockClientAsync(advisorId, userId, null, ct);
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
        await LockClientAsync(advisorId, userId, null, ct);
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
        if (!owner) await LockClientAsync(currentUserId, task.UserId, null, ct);
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
        // Use PostgreSQL's stored timestamp precision for the first and repeated completion responses.
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
