using System.IdentityModel.Tokens.Jwt;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartHealthFitness.Api.Contracts;
using SmartHealthFitness.Api.Entities;
using SmartHealthFitness.Api.Services;

namespace SmartHealthFitness.Api.Controllers;

[ApiController]
[Authorize(Policy = RoleNames.User)]
[ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
[Route("api/users/me")]
[ProducesResponseType<ProblemDetails>(StatusCodes.Status401Unauthorized, "application/problem+json")]
[ProducesResponseType<ProblemDetails>(StatusCodes.Status403Forbidden, "application/problem+json")]
public sealed class TrackingRecordsController(TrackingService trackingService) : ControllerBase
{
    private Guid CurrentUserId => Guid.Parse(User.FindFirst(JwtRegisteredClaimNames.Sub)!.Value);

    [HttpGet("weight-records")]
    [ProducesResponseType<WeightRecordResponse[]>(StatusCodes.Status200OK, "application/json")]
    public async Task<ActionResult<WeightRecordResponse[]>> GetWeightRecordsAsync(CancellationToken cancellationToken) =>
        Ok(await trackingService.GetWeightRecordsAsync(CurrentUserId, cancellationToken));

    [HttpPost("weight-records")]
    [ProducesResponseType<WeightRecordResponse>(StatusCodes.Status201Created, "application/json")]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest, "application/problem+json")]
    public async Task<ActionResult<WeightRecordResponse>> CreateWeightRecordAsync(CreateWeightRecordRequest request,
        CancellationToken cancellationToken) =>
        Created("/api/users/me/weight-records", await trackingService.CreateWeightRecordAsync(CurrentUserId, request, cancellationToken));

    [HttpGet("body-measurements")]
    [ProducesResponseType<BodyMeasurementResponse[]>(StatusCodes.Status200OK, "application/json")]
    public async Task<ActionResult<BodyMeasurementResponse[]>> GetBodyMeasurementsAsync(CancellationToken cancellationToken) =>
        Ok(await trackingService.GetBodyMeasurementsAsync(CurrentUserId, cancellationToken));

    [HttpPost("body-measurements")]
    [ProducesResponseType<BodyMeasurementResponse>(StatusCodes.Status201Created, "application/json")]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest, "application/problem+json")]
    public async Task<ActionResult<BodyMeasurementResponse>> CreateBodyMeasurementAsync(CreateBodyMeasurementRequest request,
        CancellationToken cancellationToken) =>
        Created("/api/users/me/body-measurements", await trackingService.CreateBodyMeasurementAsync(CurrentUserId, request, cancellationToken));
}
