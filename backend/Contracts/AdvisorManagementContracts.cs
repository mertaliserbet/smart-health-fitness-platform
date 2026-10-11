using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;
using SmartHealthFitness.Api.Entities;

namespace SmartHealthFitness.Api.Contracts;

public sealed record ClientSummaryResponse(Guid Id, string FirstName, string LastName,
    UserAdvisorStatus RelationshipStatus, DateOnly StartDate);

public sealed record PagedUsersResponse(RegisterResponse[] Items, int Page, int PageSize,
    int TotalCount, int TotalPages);

// Admin management also identifies the client; the existing mobile response stays unchanged.
public sealed record UserAdvisorManagementResponse(Guid UserAdvisorId, Guid UserId, Guid AdvisorId,
    AdvisorType AdvisorType, UserAdvisorStatus Status, DateOnly StartDate, DateOnly? EndDate)
{
    public static UserAdvisorManagementResponse FromRelation(UserAdvisor relation) => new(
        relation.Id, relation.UserId, relation.AdvisorId, relation.AdvisorType,
        relation.Status, relation.StartDate, relation.EndDate);
}

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class CreateUserAdvisorRequest : IValidatableObject
{
    [Required] public Guid? UserId { get; init; }
    [Required] public Guid? AdvisorId { get; init; }
    [Required, RegularExpression("^(Trainer|Dietitian)$")]
    public string AdvisorType { get; init; } = string.Empty;
    [Required] public DateOnly? StartDate { get; init; }

    public IEnumerable<ValidationResult> Validate(ValidationContext context)
    {
        if (UserId == Guid.Empty) yield return new("Geçerli bir kullanıcı seçin.", ["userId"]);
        if (AdvisorId == Guid.Empty || AdvisorId == UserId)
            yield return new("Danışman kullanıcıdan farklı olmalıdır.", ["advisorId"]);
        if (StartDate is not null && StartDate != DateOnly.FromDateTime(DateTime.UtcNow))
            yield return new("Danışman ilişkisi atama gününde başlamalıdır (UTC).", ["startDate"]);
    }
}

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class UpdateUserAdvisorRequest
{
    [Required, RegularExpression("^(Ended|Cancelled)$")]
    public string Status { get; init; } = string.Empty;
    [Required] public DateOnly? EndDate { get; init; }
}
