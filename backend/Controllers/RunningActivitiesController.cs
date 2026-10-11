using System.IdentityModel.Tokens.Jwt;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartHealthFitness.Api.Contracts;
using SmartHealthFitness.Api.Entities;
using SmartHealthFitness.Api.Services;

namespace SmartHealthFitness.Api.Controllers;

[ApiController, Authorize(Policy = RoleNames.User)]
[ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
public sealed class RunningActivitiesController(RunningService running) : ControllerBase
{
    private Guid UserId => Guid.Parse(User.FindFirst(JwtRegisteredClaimNames.Sub)!.Value);

    [HttpGet("api/users/me/running-activities")]
    public async Task<ActionResult<RunningActivitySummaryResponse[]>> GetActivities(CancellationToken ct) =>
        Ok(await running.GetActivitiesAsync(UserId, ct));

    [HttpGet("api/running-activities/{runningActivityId:guid}")]
    public async Task<ActionResult<RunningActivityResponse>> GetActivity(Guid runningActivityId, CancellationToken ct)
    {
        var run = await running.GetActivityAsync(UserId, runningActivityId, ct);
        return run is null ? NotFound(new ProblemDetails { Status = 404, Title = "Koşu kaydı bulunamadı." }) : Ok(run);
    }

    [HttpPost("api/users/me/running-activities"), RequestSizeLimit(4 * 1024 * 1024)]
    public async Task<ActionResult<RunningActivityResponse>> CreateActivity(CreateRunningActivityRequest request, CancellationToken ct)
    {
        var result = await running.CreateActivityAsync(UserId, request, ct);
        return result.Created ? Created($"/api/running-activities/{result.Activity.Id}", result.Activity) : Ok(result.Activity);
    }
}
