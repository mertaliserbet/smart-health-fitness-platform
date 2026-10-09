using System.IdentityModel.Tokens.Jwt;
using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using SmartHealthFitness.Api.Data;
using SmartHealthFitness.Api.Entities;
using SmartHealthFitness.Api.Services;

namespace SmartHealthFitness.Api.Configuration;

public static class AuthenticationConfiguration
{
    public static IServiceCollection AddBackendAuthentication(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddOptions<JwtOptions>().Bind(configuration.GetSection("Jwt"))
            .PostConfigure(options =>
            {
                options.Secret = configuration["JWT_SECRET"] ?? options.Secret;
                options.Issuer = configuration["JWT_ISSUER"] ?? options.Issuer;
                options.Audience = configuration["JWT_AUDIENCE"] ?? options.Audience;
            })
            .ValidateDataAnnotations()
            .Validate(options => Encoding.UTF8.GetByteCount(options.Secret) >= 32,
                "JWT secret must contain at least 32 bytes.")
            .ValidateOnStart();

        services.Configure<PasswordHasherOptions>(options => options.IterationCount = 210_000);
        services.AddScoped<IPasswordHasher<User>, PasswordHasher<User>>();
        services.AddScoped<TokenService>();
        services.AddScoped<AuthService>();
        services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer();
        services.AddOptions<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme)
            .Configure<IOptions<JwtOptions>>((options, jwtOptions) =>
            {
                var jwt = jwtOptions.Value;
                options.MapInboundClaims = false;
                options.IncludeErrorDetails = false;
                options.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuer = true,
                    ValidIssuer = jwt.Issuer,
                    ValidateAudience = true,
                    ValidAudience = jwt.Audience,
                    ValidateIssuerSigningKey = true,
                    IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.Secret)),
                    ValidateLifetime = true,
                    RequireExpirationTime = true,
                    RequireSignedTokens = true,
                    ValidAlgorithms = [SecurityAlgorithms.HmacSha256],
                    ClockSkew = TimeSpan.FromSeconds(5),
                    NameClaimType = JwtRegisteredClaimNames.Sub,
                    RoleClaimType = "role"
                };
                options.Events = new JwtBearerEvents
                {
                    OnTokenValidated = async context =>
                    {
                        // Public endpoints (especially health) do not need user/database authentication checks.
                        if (context.HttpContext.GetEndpoint()?.Metadata.GetMetadata<IAllowAnonymous>() is not null)
                        {
                            return;
                        }

                        var subject = context.Principal?.FindFirst(JwtRegisteredClaimNames.Sub)?.Value;
                        var dbContext = context.HttpContext.RequestServices.GetRequiredService<AppDbContext>();
                        if (!Guid.TryParse(subject, out var userId) ||
                            !await dbContext.Users.AnyAsync(user => user.Id == userId && user.IsActive,
                                context.HttpContext.RequestAborted))
                        {
                            context.Fail("Invalid user.");
                        }
                    }
                };
            });

        services.AddAuthorization(options =>
        {
            options.FallbackPolicy = new AuthorizationPolicyBuilder()
                .RequireAuthenticatedUser().RequireClaim(JwtRegisteredClaimNames.Sub).Build();
            foreach (var role in new[] { RoleNames.User, RoleNames.Trainer, RoleNames.Dietitian, RoleNames.Admin })
            {
                options.AddPolicy(role, policy => policy.RequireAuthenticatedUser().RequireRole(role));
            }
        });
        return services;
    }
}
