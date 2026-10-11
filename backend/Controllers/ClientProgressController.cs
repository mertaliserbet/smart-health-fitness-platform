using System.IdentityModel.Tokens.Jwt;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartHealthFitness.Api.Contracts;
using SmartHealthFitness.Api.Entities;
using SmartHealthFitness.Api.Services;

namespace SmartHealthFitness.Api.Controllers;

[ApiController, Authorize(Roles = RoleNames.Trainer + "," + RoleNames.Dietitian)]
[ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
[ProducesResponseType<ProblemDetails>(StatusCodes.Status401Unauthorized, "application/problem+json")]
[ProducesResponseType<ProblemDetails>(StatusCodes.Status403Forbidden, "application/problem+json")]
public sealed class ClientProgressController(AdvisorService advisors, TrackingService tracking) : ControllerBase
{
    private Guid AdvisorId => Guid.Parse(User.FindFirst(JwtRegisteredClaimNames.Sub)!.Value);

    // A single-role token must match the relationship type. A multi-role advisor may use either.
    private AdvisorType? RelationshipType => User.IsInRole(RoleNames.Trainer)
        ? User.IsInRole(RoleNames.Dietitian) ? null : AdvisorType.Trainer
        : AdvisorType.Dietitian;

    [HttpGet("api/users/{userId:guid}/weight-records")]
    [ProducesResponseType<WeightRecordResponse[]>(StatusCodes.Status200OK, "application/json")]
    public async Task<ActionResult<WeightRecordResponse[]>> GetWeightRecordsAsync(Guid userId, CancellationToken ct)
    {
        await advisors.RequireClientAsync(AdvisorId, userId, RelationshipType, ct);
        return Ok(await tracking.GetWeightRecordsAsync(userId, ct));
    }

    [HttpGet("api/users/{userId:guid}/body-measurements")]
    [ProducesResponseType<BodyMeasurementResponse[]>(StatusCodes.Status200OK, "application/json")]
    public async Task<ActionResult<BodyMeasurementResponse[]>> GetBodyMeasurementsAsync(Guid userId, CancellationToken ct)
    {
        await advisors.RequireClientAsync(AdvisorId, userId, RelationshipType, ct);
        return Ok(await tracking.GetBodyMeasurementsAsync(userId, ct));
    }
}
