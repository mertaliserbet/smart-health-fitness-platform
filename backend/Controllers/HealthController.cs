using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartHealthFitness.Api.Contracts;
using SmartHealthFitness.Api.Data;

namespace SmartHealthFitness.Api.Controllers;

[ApiController]
[Route("api/health")]
public sealed class HealthController(AppDbContext dbContext) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType<HealthResponse>(StatusCodes.Status200OK, "application/json")]
    [ProducesResponseType<ProblemDetails>(StatusCodes.Status503ServiceUnavailable, "application/problem+json")]
    public async Task<ActionResult<HealthResponse>> GetAsync(CancellationToken cancellationToken)
    {
        if (!await dbContext.Database.CanConnectAsync(cancellationToken))
        {
            return Problem(
                statusCode: StatusCodes.Status503ServiceUnavailable,
                title: "Database unavailable",
                detail: "The API could not connect to PostgreSQL.",
                instance: HttpContext.Request.Path);
        }

        return Ok(new HealthResponse("Healthy", "Connected", DateTime.UtcNow));
    }
}
