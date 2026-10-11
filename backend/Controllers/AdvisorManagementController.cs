using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartHealthFitness.Api.Contracts;
using SmartHealthFitness.Api.Entities;
using SmartHealthFitness.Api.Services;

namespace SmartHealthFitness.Api.Controllers;

[ApiController]
[Authorize(Policy = RoleNames.Admin)]
[ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
[TypeFilter(typeof(AssignmentExceptionFilter))]
public sealed class AdvisorManagementController(AdvisorService advisorService) : ControllerBase
{
    [HttpGet("api/users")]
    public async Task<ActionResult<PagedUsersResponse>> GetUsersAsync(
        [FromQuery, Range(1, 1000000)] int page = 1, [FromQuery, Range(1, 100)] int pageSize = 20,
        [FromQuery] string? role = null, [FromQuery, StringLength(200)] string? search = null,
        CancellationToken cancellationToken = default) =>
        Ok(await advisorService.GetUsersAsync(page, pageSize, role, search, cancellationToken));

    [HttpGet("api/user-advisors")]
    public async Task<ActionResult<UserAdvisorManagementResponse[]>> GetRelationsAsync([FromQuery, Required] Guid? userId,
        CancellationToken cancellationToken) =>
        Ok(await advisorService.GetRelationsAsync(userId!.Value, cancellationToken));

    [HttpPost("api/user-advisors")]
    public async Task<ActionResult<UserAdvisorManagementResponse>> CreateRelationAsync(CreateUserAdvisorRequest request,
        CancellationToken cancellationToken)
    {
        var relation = await advisorService.CreateRelationAsync(request, cancellationToken);
        return Created($"/api/user-advisors?userId={relation.UserId}", relation);
    }

    [HttpPatch("api/user-advisors/{userAdvisorId:guid}")]
    public async Task<ActionResult<UserAdvisorManagementResponse>> EndRelationAsync(Guid userAdvisorId,
        UpdateUserAdvisorRequest request, CancellationToken cancellationToken) =>
        Ok(await advisorService.EndRelationAsync(userAdvisorId, request, cancellationToken));
}
