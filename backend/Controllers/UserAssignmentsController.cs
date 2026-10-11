using System.Globalization;
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
public sealed class UserAssignmentsController(AdvisorService advisorService, WorkoutService workoutService,
    NutritionService nutritionService) : ControllerBase
{
    private Guid CurrentUserId => Guid.Parse(User.FindFirst(JwtRegisteredClaimNames.Sub)!.Value);

    [HttpGet("advisors")]
    [ProducesResponseType<UserAdvisorResponse[]>(StatusCodes.Status200OK, "application/json")]
    public async Task<ActionResult<UserAdvisorResponse[]>> GetAdvisorsAsync(CancellationToken cancellationToken) =>
        Ok(await advisorService.GetUserAdvisorsAsync(CurrentUserId, cancellationToken));

    [HttpGet("advisor-notes")]
    [ProducesResponseType<AdvisorNoteResponse[]>(StatusCodes.Status200OK, "application/json")]
    public async Task<ActionResult<AdvisorNoteResponse[]>> GetNotesAsync(CancellationToken cancellationToken) =>
        Ok(await advisorService.GetAdvisorNotesAsync(CurrentUserId, cancellationToken));

    [HttpGet("tasks")]
    [ProducesResponseType<UserTaskResponse[]>(StatusCodes.Status200OK, "application/json")]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest, "application/problem+json")]
    public async Task<ActionResult<UserTaskResponse[]>> GetTasksAsync([FromQuery] string? status,
        CancellationToken cancellationToken)
    {
        UserTaskStatus? filter = null;
        if (status is not null)
        {
            if (!Enum.TryParse<UserTaskStatus>(status, out var parsed) || parsed.ToString() != status || !Enum.IsDefined(parsed))
            {
                ModelState.AddModelError("status", "Status must be Pending, InProgress, Completed or Cancelled.");
                return ValidationProblem(ModelState);
            }
            filter = parsed;
        }
        return Ok(await advisorService.GetUserTasksAsync(CurrentUserId, filter, cancellationToken));
    }

    [HttpGet("workout-plans")]
    [ProducesResponseType<WorkoutPlanSummaryResponse[]>(StatusCodes.Status200OK, "application/json")]
    public async Task<ActionResult<WorkoutPlanSummaryResponse[]>> GetWorkoutPlansAsync(CancellationToken cancellationToken) =>
        Ok(await workoutService.GetWorkoutPlansAsync(CurrentUserId, cancellationToken));

    [HttpGet("nutrition-goals/active")]
    [ProducesResponseType<NutritionGoalResponse>(StatusCodes.Status200OK, "application/json")]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status404NotFound, "application/problem+json")]
    [ProducesResponseType<ValidationProblemDetails>(StatusCodes.Status400BadRequest, "application/problem+json")]
    public async Task<ActionResult<NutritionGoalResponse>> GetActiveNutritionGoalAsync([FromQuery] string? date,
        CancellationToken cancellationToken)
    {
        var calendarDate = DateOnly.FromDateTime(DateTime.UtcNow);
        if (date is not null && !DateOnly.TryParseExact(date, "yyyy-MM-dd", CultureInfo.InvariantCulture,
            DateTimeStyles.None, out calendarDate))
        {
            ModelState.AddModelError("date", "Date must be a valid YYYY-MM-DD calendar date.");
            return ValidationProblem(ModelState);
        }
        var goal = await nutritionService.GetActiveNutritionGoalAsync(CurrentUserId, calendarDate, cancellationToken);
        if (goal is not null) return Ok(goal);
        return Problem(statusCode: StatusCodes.Status404NotFound, title: "No active nutrition goal",
            extensions: new Dictionary<string, object?> { ["code"] = "NutritionGoalNotFound" });
    }
}
