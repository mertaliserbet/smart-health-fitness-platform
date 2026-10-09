using SmartHealthFitness.Api.Entities;

namespace SmartHealthFitness.Api.Contracts;

public sealed record UserProfileResponse(
    Guid Id, string FirstName, string LastName, string Email,
    string? PhoneNumber, DateOnly? BirthDate, string? Gender, decimal? HeightCm, string[] Roles)
{
    public static UserProfileResponse FromUser(User user) => new(
        user.Id, user.FirstName, user.LastName, user.Email,
        user.PhoneNumber, user.BirthDate, user.Gender, user.HeightCm,
        user.UserRoles.Select(userRole => userRole.Role.Name).Order().ToArray());
}
