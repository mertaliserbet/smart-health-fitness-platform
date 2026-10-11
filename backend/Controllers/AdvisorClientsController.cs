using System.IdentityModel.Tokens.Jwt;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartHealthFitness.Api.Contracts;
using SmartHealthFitness.Api.Entities;
using SmartHealthFitness.Api.Services;

namespace SmartHealthFitness.Api.Controllers;

[ApiController]
[Authorize]
[ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
public sealed class AdvisorClientsController(AdvisorService advisorService, WorkoutService workoutService,
    NutritionService nutritionService) : ControllerBase
{
    private Guid CurrentUserId => Guid.Parse(User.FindFirst(JwtRegisteredClaimNames.Sub)!.Value);

    [HttpGet("api/trainers/me/clients"), Authorize(Policy = RoleNames.Trainer)]
    public async Task<ActionResult<ClientSummaryResponse[]>> GetTrainerClientsAsync(CancellationToken cancellationToken) =>
        Ok(await advisorService.GetClientsAsync(CurrentUserId, AdvisorType.Trainer, cancellationToken));

    [HttpGet("api/dietitians/me/clients"), Authorize(Policy = RoleNames.Dietitian)]
    public async Task<ActionResult<ClientSummaryResponse[]>> GetDietitianClientsAsync(CancellationToken cancellationToken) =>
        Ok(await advisorService.GetClientsAsync(CurrentUserId, AdvisorType.Dietitian, cancellationToken));

    // Client management route; the auth-owned /users/me implementation is reused as-is.
    [HttpGet("api/users/{userId:guid}"), Authorize(Roles = RoleNames.Trainer + "," + RoleNames.Dietitian + "," + RoleNames.Admin)]
    public async Task<ActionResult<UserProfileResponse>> GetClientProfileAsync(Guid userId, CancellationToken cancellationToken) =>
        Ok(await advisorService.GetClientProfileAsync(userId, CurrentUserId, User.IsInRole(RoleNames.Admin),
            User.IsInRole(RoleNames.Trainer), User.IsInRole(RoleNames.Dietitian), cancellationToken));

    [HttpGet("api/users/{userId:guid}/workout-plans"), Authorize(Policy = RoleNames.Trainer)]
    public async Task<ActionResult<WorkoutPlanSummaryResponse[]>> GetClientWorkoutPlansAsync(Guid userId,
        CancellationToken cancellationToken)
    {
        await advisorService.RequireClientAsync(CurrentUserId, userId, AdvisorType.Trainer, cancellationToken);
        return Ok(await workoutService.GetWorkoutPlansAsync(userId, cancellationToken));
    }

    [HttpPost("api/users/{userId:guid}/workout-plans"), Authorize(Policy = RoleNames.Trainer)]
    public async Task<ActionResult<WorkoutPlanResponse>> CreateWorkoutPlanAsync(Guid userId, CreateWorkoutPlanRequest request,
        CancellationToken cancellationToken)
    {
        var plan = await workoutService.CreatePlanAsync(userId, CurrentUserId, request, cancellationToken);
        return Created($"/api/workout-plans/{plan.Id}", plan);
    }

    [HttpGet("api/users/{userId:guid}/nutrition-goals"), Authorize(Policy = RoleNames.Dietitian)]
    public async Task<ActionResult<NutritionGoalResponse[]>> GetClientNutritionGoalsAsync(Guid userId,
        CancellationToken cancellationToken)
    {
        await advisorService.RequireClientAsync(CurrentUserId, userId, AdvisorType.Dietitian, cancellationToken);
        return Ok(await nutritionService.GetNutritionGoalsAsync(userId, cancellationToken));
    }

    [HttpPost("api/users/{userId:guid}/nutrition-goals"), Authorize(Policy = RoleNames.Dietitian)]
    public async Task<ActionResult<NutritionGoalResponse>> CreateNutritionGoalAsync(Guid userId,
        CreateNutritionGoalRequest request, CancellationToken cancellationToken)
    {
        var goal = await nutritionService.CreateNutritionGoalAsync(userId, CurrentUserId, request, cancellationToken);
        return Created($"/api/users/{userId}/nutrition-goals", goal);
    }

    [HttpGet("api/users/{userId:guid}/tasks"), Authorize(Roles = RoleNames.Trainer + "," + RoleNames.Dietitian)]
    public async Task<ActionResult<UserTaskResponse[]>> GetTasksAsync(Guid userId, CancellationToken ct)
    {
        await advisorService.RequireClientAsync(CurrentUserId, userId, null, ct);
        return Ok(await advisorService.GetUserTasksAsync(userId, null, ct));
    }

    [HttpPost("api/users/{userId:guid}/tasks"), Authorize(Roles = RoleNames.Trainer + "," + RoleNames.Dietitian)]
    public async Task<ActionResult<UserTaskResponse>> CreateTaskAsync(Guid userId,
        CreateUserTaskRequest request, CancellationToken ct) =>
        StatusCode(201, await advisorService.CreateTaskAsync(userId, CurrentUserId, request, ct));

    [HttpGet("api/users/{userId:guid}/advisor-notes"), Authorize(Roles = RoleNames.Trainer + "," + RoleNames.Dietitian)]
    public async Task<ActionResult<AdvisorNoteResponse[]>> GetNotesAsync(Guid userId, CancellationToken ct)
    {
        await advisorService.RequireClientAsync(CurrentUserId, userId, null, ct);
        return Ok(await advisorService.GetAdvisorNotesAsync(userId, ct));
    }

    [HttpPost("api/users/{userId:guid}/advisor-notes"), Authorize(Roles = RoleNames.Trainer + "," + RoleNames.Dietitian)]
    public async Task<ActionResult<AdvisorNoteResponse>> CreateNoteAsync(Guid userId,
        CreateAdvisorNoteRequest request, CancellationToken ct) =>
        StatusCode(201, await advisorService.CreateNoteAsync(userId, CurrentUserId, request, ct));
}
