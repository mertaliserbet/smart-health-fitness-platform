using Microsoft.EntityFrameworkCore;
using SmartHealthFitness.Api.Contracts;
using SmartHealthFitness.Api.Data;
using SmartHealthFitness.Api.Entities;

namespace SmartHealthFitness.Api.Services;

public sealed class AdvisorService(AppDbContext dbContext)
{
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
