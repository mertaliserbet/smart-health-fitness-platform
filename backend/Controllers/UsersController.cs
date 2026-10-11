using System.IdentityModel.Tokens.Jwt;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartHealthFitness.Api.Contracts;
using SmartHealthFitness.Api.Services;
using SmartHealthFitness.Api.Entities;

namespace SmartHealthFitness.Api.Controllers;

[ApiController]
[ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
[Authorize]
[Route("api/users")]
public sealed class UsersController(AuthService authService, AdvisorService advisorService) : ControllerBase
{
    [HttpGet("{userId:guid}")]
    [Authorize(Roles = RoleNames.Trainer + "," + RoleNames.Dietitian + "," + RoleNames.Admin)]
    public async Task<ActionResult<UserProfileResponse>> GetClient(Guid userId, CancellationToken ct)
    {
        if (!User.IsInRole(RoleNames.Admin))
            await advisorService.RequireClientAsync(userId, Guid.Parse(User.FindFirst(JwtRegisteredClaimNames.Sub)!.Value), null, ct);
        var response = await authService.GetUserAsync(userId, ct);
        return response is null ? NotFound() : Ok(response);
    }

    [HttpGet("me")]
    [ProducesResponseType<UserProfileResponse>(StatusCodes.Status200OK, "application/json")]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status401Unauthorized, "application/problem+json")]
    public async Task<ActionResult<UserProfileResponse>> GetMeAsync(CancellationToken cancellationToken)
    {
        var userId = Guid.Parse(User.FindFirst(JwtRegisteredClaimNames.Sub)!.Value);
        var response = await authService.GetUserAsync(userId, cancellationToken);
        return response is null ? Unauthorized() : Ok(response);
    }
}
