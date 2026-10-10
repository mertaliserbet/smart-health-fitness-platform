using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;
using SmartHealthFitness.Api.Entities;
using SmartHealthFitness.Api.Validation;

namespace SmartHealthFitness.Api.Contracts;

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class RegisterRequest
{
    [Required, StringLength(100), PersonName] public string FirstName { get; init; } = string.Empty;
    [Required, StringLength(100), PersonName] public string LastName { get; init; } = string.Empty;
    [Required, EmailAddress, StringLength(254)] public string Email { get; init; } = string.Empty;
    [Required, StringLength(128, MinimumLength = 12)] public string Password { get; init; } = string.Empty;
}

public sealed class LoginRequest
{
    [Required, EmailAddress, StringLength(254)] public string Email { get; init; } = string.Empty;
    [Required, StringLength(128)] public string Password { get; init; } = string.Empty;
}

public sealed class RefreshTokenRequest
{
    [Required, StringLength(256)] public string RefreshToken { get; init; } = string.Empty;
}

public sealed class LogoutRequest
{
    [Required, StringLength(256)] public string RefreshToken { get; init; } = string.Empty;
}

public sealed record RegisterResponse(Guid Id, string FirstName, string LastName, string Email, string[] Roles)
{
    public static RegisterResponse FromUser(User user) => new(
        user.Id, user.FirstName, user.LastName, user.Email,
        user.UserRoles.Select(userRole => userRole.Role.Name).Order().ToArray());
}

public sealed record LoginResponse(string AccessToken, string RefreshToken, DateTime ExpiresAt, RegisterResponse User);

public sealed record RefreshTokenResponse(string AccessToken, string RefreshToken, DateTime ExpiresAt);
