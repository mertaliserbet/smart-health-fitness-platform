using System.IdentityModel.Tokens.Jwt;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartHealthFitness.Api.Contracts;
using SmartHealthFitness.Api.Entities;
using SmartHealthFitness.Api.Services;

namespace SmartHealthFitness.Api.Controllers;

[ApiController, Authorize]
[ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
public sealed class WorkoutSessionsController(WorkoutSessionService sessions) : ControllerBase
{
    private Guid UserId => Guid.Parse(User.FindFirst(JwtRegisteredClaimNames.Sub)!.Value);

    [HttpPost("api/workout-sessions"), Authorize(Policy = RoleNames.User)]
    public async Task<ActionResult<WorkoutSessionResponse>> StartAsync(StartWorkoutSessionRequest request, CancellationToken ct)
    {
        var result = await sessions.StartAsync(UserId, request, ct);
        return result.Created ? Created($"/api/workout-sessions/{result.Session.Id}", result.Session) : Ok(result.Session);
    }

    [HttpPut("api/workout-sessions/{sessionId:guid}/exercises/{workoutExerciseId:guid}"), Authorize(Policy = RoleNames.User)]
    public async Task<ActionResult<WorkoutLogResponse>> SaveLogAsync(Guid sessionId, Guid workoutExerciseId,
        SaveWorkoutLogRequest request, CancellationToken ct) =>
        Ok(await sessions.SaveLogAsync(UserId, sessionId, workoutExerciseId, request, ct));

    [HttpPost("api/workout-sessions/{sessionId:guid}/complete"), Authorize(Policy = RoleNames.User)]
    public async Task<ActionResult<WorkoutSessionResponse>> CompleteAsync(Guid sessionId, CancellationToken ct) =>
        Ok(await sessions.FinishAsync(UserId, sessionId, WorkoutSessionStatus.Completed, ct));

    [HttpPost("api/workout-sessions/{sessionId:guid}/cancel"), Authorize(Policy = RoleNames.User)]
    public async Task<ActionResult<WorkoutSessionResponse>> CancelAsync(Guid sessionId, CancellationToken ct) =>
        Ok(await sessions.FinishAsync(UserId, sessionId, WorkoutSessionStatus.Cancelled, ct));

    [HttpGet("api/users/me/workout-sessions"), Authorize(Policy = RoleNames.User)]
    public async Task<ActionResult<PagedWorkoutSessionsResponse>> GetHistoryAsync([FromQuery] WorkoutSessionQuery query, CancellationToken ct) =>
        Ok(await sessions.GetHistoryAsync(UserId, query, ct));

    [HttpGet("api/users/{userId:guid}/workout-sessions"), Authorize(Policy = RoleNames.Trainer)]
    public async Task<ActionResult<PagedWorkoutSessionsResponse>> GetClientHistoryAsync(Guid userId,
        [FromQuery] WorkoutSessionQuery query, CancellationToken ct) =>
        Ok(await sessions.GetClientHistoryAsync(UserId, userId, query, ct));

    [HttpGet("api/workout-sessions/{sessionId:guid}"), Authorize(Roles = RoleNames.User + "," + RoleNames.Trainer)]
    public async Task<ActionResult<WorkoutSessionResponse>> GetAsync(Guid sessionId, CancellationToken ct)
    {
        var session = await sessions.GetAsync(sessionId, UserId, User.IsInRole(RoleNames.User), User.IsInRole(RoleNames.Trainer), ct);
        return session is null ? Problem(statusCode: 404, title: "Antrenman bulunamadı.") : Ok(session);
    }
}
