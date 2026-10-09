using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using SmartHealthFitness.Api.Contracts;
using SmartHealthFitness.Api.Data;
using SmartHealthFitness.Api.Entities;

namespace SmartHealthFitness.Api.Services;

public sealed class AuthService(AppDbContext dbContext, IPasswordHasher<User> passwordHasher, TokenService tokenService)
{
    public async Task<RegisterResponse?> RegisterAsync(RegisterRequest request, CancellationToken cancellationToken)
    {
        var email = NormalizeEmail(request.Email);
        if (await dbContext.Users.AnyAsync(user => user.Email == email, cancellationToken))
        {
            return null;
        }

        var role = await dbContext.Roles.SingleAsync(role => role.Name == RoleNames.User, cancellationToken);
        var user = new User { FirstName = request.FirstName.Trim(), LastName = request.LastName.Trim(), Email = email };
        user.PasswordHash = passwordHasher.HashPassword(user, request.Password);
        user.UserRoles.Add(new UserRole { Role = role });
        dbContext.Users.Add(user);

        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException exception) when (exception.InnerException is PostgresException
               { SqlState: PostgresErrorCodes.UniqueViolation, ConstraintName: "ux_users_email" })
        {
            // The unique index also protects simultaneous registrations of the same email.
            return null;
        }

        return RegisterResponse.FromUser(user);
    }

    public async Task<LoginResponse?> LoginAsync(LoginRequest request, CancellationToken cancellationToken)
    {
        var email = NormalizeEmail(request.Email);
        var user = await UsersWithRoles().SingleOrDefaultAsync(user => user.Email == email, cancellationToken);
        if (user is null || !user.IsActive)
        {
            return null;
        }

        var result = passwordHasher.VerifyHashedPassword(user, user.PasswordHash, request.Password);
        if (result == PasswordVerificationResult.Failed)
        {
            return null;
        }

        if (result == PasswordVerificationResult.SuccessRehashNeeded)
        {
            user.PasswordHash = passwordHasher.HashPassword(user, request.Password);
            user.UpdatedAt = DateTime.UtcNow;
        }

        var accessToken = tokenService.CreateAccessToken(user);
        var refreshToken = tokenService.CreateRefreshToken(user.Id);
        dbContext.RefreshTokens.Add(refreshToken.Record);
        await dbContext.SaveChangesAsync(cancellationToken);
        return new LoginResponse(accessToken.Token, refreshToken.Token, accessToken.ExpiresAt, RegisterResponse.FromUser(user));
    }

    public async Task<RefreshTokenResponse?> RefreshAsync(RefreshTokenRequest request, CancellationToken cancellationToken)
    {
        var hash = TokenService.HashRefreshToken(request.RefreshToken);
        var now = DateTime.UtcNow;
        await using var transaction = await dbContext.Database.BeginTransactionAsync(cancellationToken);
        var token = await dbContext.RefreshTokens.AsNoTracking()
            .Include(token => token.User).ThenInclude(user => user.UserRoles).ThenInclude(userRole => userRole.Role)
            .SingleOrDefaultAsync(token => token.TokenHash == hash, cancellationToken);
        if (token is null || token.RevokedAt is not null || token.ExpiresAt <= now || !token.User.IsActive)
        {
            return null;
        }

        // Conditional UPDATE permits only one winner, even if refresh requests arrive together.
        var updated = await dbContext.RefreshTokens
            .Where(record => record.Id == token.Id && record.RevokedAt == null && record.ExpiresAt > now && record.User.IsActive)
            .ExecuteUpdateAsync(setters => setters.SetProperty(record => record.RevokedAt, (DateTime?)now), cancellationToken);
        if (updated != 1)
        {
            return null;
        }

        var accessToken = tokenService.CreateAccessToken(token.User);
        var refreshToken = tokenService.CreateRefreshToken(token.UserId);
        dbContext.RefreshTokens.Add(refreshToken.Record);
        await dbContext.SaveChangesAsync(cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        return new RefreshTokenResponse(accessToken.Token, refreshToken.Token, accessToken.ExpiresAt);
    }

    public async Task<UserProfileResponse?> GetUserAsync(Guid userId, CancellationToken cancellationToken)
    {
        var user = await UsersWithRoles().AsNoTracking()
            .SingleOrDefaultAsync(user => user.Id == userId && user.IsActive, cancellationToken);
        return user is null ? null : UserProfileResponse.FromUser(user);
    }

    public async Task<bool> LogoutAsync(Guid userId, LogoutRequest request, CancellationToken cancellationToken)
    {
        var hash = TokenService.HashRefreshToken(request.RefreshToken);
        var token = await dbContext.RefreshTokens.AsNoTracking()
            .SingleOrDefaultAsync(token => token.TokenHash == hash, cancellationToken);
        if (token is null)
        {
            return true;
        }

        if (token.UserId != userId)
        {
            return false;
        }

        await dbContext.RefreshTokens.Where(record => record.Id == token.Id && record.RevokedAt == null)
            .ExecuteUpdateAsync(setters => setters.SetProperty(record => record.RevokedAt, (DateTime?)DateTime.UtcNow), cancellationToken);
        return true;
    }

    private IQueryable<User> UsersWithRoles() =>
        dbContext.Users.Include(user => user.UserRoles).ThenInclude(userRole => userRole.Role);

    private static string NormalizeEmail(string email) => email.Trim().ToLowerInvariant();
}
