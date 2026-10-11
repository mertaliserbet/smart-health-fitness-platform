using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartHealthFitness.Api.Contracts;
using SmartHealthFitness.Api.Entities;
using SmartHealthFitness.Api.Services;

namespace SmartHealthFitness.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/exercises")]
[ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
public sealed class ExercisesController(ExerciseService exerciseService) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType(typeof(ExerciseResponse[]), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetExercisesAsync([FromQuery, StringLength(200)] string? search,
        [FromQuery] Guid? muscleGroupId, [FromQuery] bool includeInactive, CancellationToken cancellationToken)
    {
        if (includeInactive && !User.IsInRole(RoleNames.Admin)) return Forbid();
        if (muscleGroupId is not null)
            throw AssignmentException.Invalid("muscleGroupId", "Kas grubu filtreleme bu aşamada desteklenmiyor.");
        if (includeInactive)
            return Ok(await exerciseService.GetManagedExercisesAsync(search, cancellationToken));
        return Ok(await exerciseService.GetExercisesAsync(search, cancellationToken));
    }

    [HttpGet("{exerciseId:guid}")]
    public async Task<ActionResult<ExerciseDetailResponse>> GetExerciseAsync(Guid exerciseId, CancellationToken cancellationToken) =>
        Ok(await exerciseService.GetExerciseAsync(exerciseId, User.IsInRole(RoleNames.Admin), cancellationToken));

    [HttpPost, Authorize(Policy = RoleNames.Admin)]
    public async Task<ActionResult<ExerciseDetailResponse>> CreateExerciseAsync(CreateExerciseRequest request,
        CancellationToken cancellationToken)
    {
        var exercise = await exerciseService.SaveExerciseAsync(null, request, cancellationToken);
        return Created($"/api/exercises/{exercise.Id}", exercise);
    }

    [HttpPut("{exerciseId:guid}"), Authorize(Policy = RoleNames.Admin)]
    public async Task<ActionResult<ExerciseDetailResponse>> UpdateExerciseAsync(Guid exerciseId, CreateExerciseRequest request,
        CancellationToken cancellationToken) =>
        Ok(await exerciseService.SaveExerciseAsync(exerciseId, request, cancellationToken));
}
