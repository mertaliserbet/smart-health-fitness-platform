using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartHealthFitness.Api.Contracts;
using SmartHealthFitness.Api.Services;

namespace SmartHealthFitness.Api.Controllers;

[ApiController, Authorize, Route("api/exercises")]
public sealed class ExercisesController(WorkoutService workouts) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<ExerciseResponse[]>> GetExercises([FromQuery] string? search, CancellationToken ct) =>
        Ok(await workouts.GetExercisesAsync(search?.Trim(), ct));
}
