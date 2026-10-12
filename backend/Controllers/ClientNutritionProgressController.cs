using System.IdentityModel.Tokens.Jwt;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartHealthFitness.Api.Contracts;
using SmartHealthFitness.Api.Entities;
using SmartHealthFitness.Api.Services;

namespace SmartHealthFitness.Api.Controllers;

[ApiController, Authorize(Roles = RoleNames.Dietitian)]
[ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
[ProducesResponseType<ProblemDetails>(StatusCodes.Status401Unauthorized, "application/problem+json")]
[ProducesResponseType<ProblemDetails>(StatusCodes.Status403Forbidden, "application/problem+json")]
public sealed class ClientNutritionProgressController(AdvisorService advisors, NutritionService nutrition) : ControllerBase
{
    [HttpGet("api/users/{userId:guid}/nutrition-records")]
    [ProducesResponseType<NutritionRecordResponse[]>(StatusCodes.Status200OK, "application/json")]
    public async Task<ActionResult<NutritionRecordResponse[]>> GetRecordsAsync(Guid userId, CancellationToken ct)
    {
        var advisorId = Guid.Parse(User.FindFirst(JwtRegisteredClaimNames.Sub)!.Value);
        await advisors.RequireClientAsync(advisorId, userId, AdvisorType.Dietitian, ct);
        return Ok(await nutrition.GetRecordsAsync(userId, null, null, null, ct));
    }
}
