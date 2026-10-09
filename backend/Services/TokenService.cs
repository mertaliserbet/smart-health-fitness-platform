using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.WebUtilities;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using SmartHealthFitness.Api.Configuration;
using SmartHealthFitness.Api.Entities;

namespace SmartHealthFitness.Api.Services;

public sealed class TokenService(IOptions<JwtOptions> options)
{
    private readonly JwtOptions _options = options.Value;

    public (string Token, DateTime ExpiresAt) CreateAccessToken(User user)
    {
        var now = DateTime.UtcNow;
        var expiresAt = now.AddMinutes(_options.AccessTokenMinutes);
        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, user.Id.ToString()),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
            new(JwtRegisteredClaimNames.Iat, new DateTimeOffset(now).ToUnixTimeSeconds().ToString(), ClaimValueTypes.Integer64)
        };
        claims.AddRange(user.UserRoles.Select(userRole => new Claim("role", userRole.Role.Name)));

        var token = new JwtSecurityToken(
            _options.Issuer, _options.Audience, claims, now, expiresAt,
            new SigningCredentials(new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_options.Secret)),
                SecurityAlgorithms.HmacSha256));

        return (new JwtSecurityTokenHandler().WriteToken(token), expiresAt);
    }

    public (string Token, RefreshToken Record) CreateRefreshToken(Guid userId)
    {
        var token = WebEncoders.Base64UrlEncode(RandomNumberGenerator.GetBytes(64));
        var now = DateTime.UtcNow;
        return (token, new RefreshToken
        {
            UserId = userId,
            TokenHash = HashRefreshToken(token),
            CreatedAt = now,
            ExpiresAt = now.AddDays(_options.RefreshTokenDays)
        });
    }

    public static string HashRefreshToken(string token) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
}
