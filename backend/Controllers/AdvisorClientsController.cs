using System.IdentityModel.Tokens.Jwt;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartHealthFitness.Api.Contracts;
using SmartHealthFitness.Api.Entities;
using SmartHealthFitness.Api.Services;

namespace SmartHealthFitness.Api.Controllers;

[ApiController]
[Authorize(Roles = RoleNames.Trainer + "," + RoleNames.Dietitian)]
[ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
public sealed class AdvisorClientsController(AdvisorService advisors, WorkoutService workouts,
    NutritionService nutrition) : ControllerBase
{
    private Guid AdvisorId => Guid.Parse(User.FindFirst(JwtRegisteredClaimNames.Sub)!.Value);

    [Authorize(Policy = RoleNames.Trainer), HttpGet("api/trainers/me/clients")]
    public async Task<ActionResult<ClientSummaryResponse[]>> GetTrainerClients(CancellationToken ct) =>
        Ok(await advisors.GetClientsAsync(AdvisorId, AdvisorType.Trainer, ct));

    [Authorize(Policy = RoleNames.Dietitian), HttpGet("api/dietitians/me/clients")]
    public async Task<ActionResult<ClientSummaryResponse[]>> GetDietitianClients(CancellationToken ct) =>
        Ok(await advisors.GetClientsAsync(AdvisorId, AdvisorType.Dietitian, ct));

    [Authorize(Policy = RoleNames.Trainer), HttpGet("api/users/{userId:guid}/workout-plans")]
    public async Task<ActionResult<WorkoutPlanSummaryResponse[]>> GetPlans(Guid userId, CancellationToken ct)
    {
        await advisors.RequireClientAsync(userId, AdvisorId, AdvisorType.Trainer, ct);
        return Ok(await workouts.GetWorkoutPlansAsync(userId, ct));
    }

    [Authorize(Policy = RoleNames.Trainer), HttpPost("api/users/{userId:guid}/workout-plans")]
    [ProducesResponseType<WorkoutPlanResponse>(StatusCodes.Status201Created)]
    public async Task<ActionResult<WorkoutPlanResponse>> CreatePlan(Guid userId,
        CreateWorkoutPlanRequest request, CancellationToken ct)
    {
        var response = await workouts.CreatePlanAsync(userId, AdvisorId, request, ct);
        return Created($"/api/workout-plans/{response.Id}", response);
    }

    [Authorize(Policy = RoleNames.Dietitian), HttpGet("api/users/{userId:guid}/nutrition-goals")]
    public async Task<ActionResult<NutritionGoalResponse[]>> GetGoals(Guid userId, CancellationToken ct)
    {
        await advisors.RequireClientAsync(userId, AdvisorId, AdvisorType.Dietitian, ct);
        return Ok(await nutrition.GetGoalsAsync(userId, ct));
    }

    [Authorize(Policy = RoleNames.Dietitian), HttpPost("api/users/{userId:guid}/nutrition-goals")]
    [ProducesResponseType<NutritionGoalResponse>(StatusCodes.Status201Created)]
    public async Task<ActionResult<NutritionGoalResponse>> CreateGoal(Guid userId,
        CreateNutritionGoalRequest request, CancellationToken ct) =>
        StatusCode(201, await nutrition.CreateGoalAsync(userId, AdvisorId, request, ct));

    [HttpGet("api/users/{userId:guid}/tasks")]
    public async Task<ActionResult<UserTaskResponse[]>> GetTasks(Guid userId, CancellationToken ct)
    {
        await advisors.RequireClientAsync(userId, AdvisorId, null, ct);
        return Ok(await advisors.GetUserTasksAsync(userId, null, ct));
    }

    [HttpPost("api/users/{userId:guid}/tasks")]
    [ProducesResponseType<UserTaskResponse>(StatusCodes.Status201Created)]
    public async Task<ActionResult<UserTaskResponse>> CreateTask(Guid userId,
        CreateUserTaskRequest request, CancellationToken ct) =>
        StatusCode(201, await advisors.CreateTaskAsync(userId, AdvisorId, request, ct));

    [HttpGet("api/users/{userId:guid}/advisor-notes")]
    public async Task<ActionResult<AdvisorNoteResponse[]>> GetNotes(Guid userId, CancellationToken ct)
    {
        await advisors.RequireClientAsync(userId, AdvisorId, null, ct);
        return Ok(await advisors.GetAdvisorNotesAsync(userId, ct));
    }

    [HttpPost("api/users/{userId:guid}/advisor-notes")]
    [ProducesResponseType<AdvisorNoteResponse>(StatusCodes.Status201Created)]
    public async Task<ActionResult<AdvisorNoteResponse>> CreateNote(Guid userId,
        CreateAdvisorNoteRequest request, CancellationToken ct) =>
        StatusCode(201, await advisors.CreateNoteAsync(userId, AdvisorId, request, ct));
}
