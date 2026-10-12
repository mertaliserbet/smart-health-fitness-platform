using System.IdentityModel.Tokens.Jwt;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartHealthFitness.Api.Contracts;
using SmartHealthFitness.Api.Entities;
using SmartHealthFitness.Api.Services;

namespace SmartHealthFitness.Api.Controllers;

[ApiController]
[Authorize(Roles = RoleNames.User + "," + RoleNames.Trainer)]
[ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
[Route("api/workout-plans")]
public sealed class WorkoutPlansController(WorkoutService workoutService) : ControllerBase
{
    [HttpPut("{workoutPlanId:guid}")]
    [Authorize(Roles = RoleNames.Trainer)]
    [ProducesResponseType<WorkoutPlanResponse>(StatusCodes.Status200OK, "application/json")]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest, "application/problem+json")]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status404NotFound, "application/problem+json")]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status409Conflict, "application/problem+json")]
    public async Task<ActionResult<WorkoutPlanResponse>> UpdateWorkoutPlanAsync(Guid workoutPlanId,
        UpdateWorkoutPlanRequest request, CancellationToken cancellationToken)
    {
        var trainerId = Guid.Parse(User.FindFirst(JwtRegisteredClaimNames.Sub)!.Value);
        return Ok(await workoutService.UpdatePlanAsync(workoutPlanId, trainerId, request, cancellationToken));
    }

    [HttpGet("{workoutPlanId:guid}")]
    [ProducesResponseType<WorkoutPlanResponse>(StatusCodes.Status200OK, "application/json")]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status404NotFound, "application/problem+json")]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status401Unauthorized, "application/problem+json")]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status403Forbidden, "application/problem+json")]
    public async Task<ActionResult<WorkoutPlanResponse>> GetWorkoutPlanAsync(Guid workoutPlanId,
        CancellationToken cancellationToken)
    {
        var userId = Guid.Parse(User.FindFirst(JwtRegisteredClaimNames.Sub)!.Value);
        var plan = await workoutService.GetWorkoutPlanAsync(workoutPlanId, userId, User.IsInRole(RoleNames.User),
            User.IsInRole(RoleNames.Trainer), cancellationToken);
        return plan is null ? Problem(statusCode: StatusCodes.Status404NotFound, title: "Workout plan not found") : Ok(plan);
    }
}
