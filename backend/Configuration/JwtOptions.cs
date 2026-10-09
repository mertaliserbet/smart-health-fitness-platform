using System.ComponentModel.DataAnnotations;

namespace SmartHealthFitness.Api.Configuration;

public sealed class JwtOptions
{
    [Required] public string Issuer { get; set; } = string.Empty;
    [Required] public string Audience { get; set; } = string.Empty;
    [Required] public string Secret { get; set; } = string.Empty;
    [Range(1, 60)] public int AccessTokenMinutes { get; set; }
    [Range(1, 30)] public int RefreshTokenDays { get; set; }
}
