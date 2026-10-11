using System.IdentityModel.Tokens.Jwt;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartHealthFitness.Api.Contracts;
using SmartHealthFitness.Api.Entities;
using SmartHealthFitness.Api.Services;

namespace SmartHealthFitness.Api.Controllers;

[ApiController, Route("api/tasks")]
[Authorize(Roles = RoleNames.User + "," + RoleNames.Trainer + "," + RoleNames.Dietitian)]
[ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
public sealed class TasksController(AdvisorService advisors) : ControllerBase
{
    [HttpPatch("{taskId:guid}")]
    public async Task<ActionResult<UserTaskResponse>> UpdateStatus(Guid taskId,
        UpdateTaskStatusRequest request, CancellationToken ct) =>
        Ok(await advisors.UpdateTaskAsync(taskId, Guid.Parse(User.FindFirst(JwtRegisteredClaimNames.Sub)!.Value),
            User.IsInRole(RoleNames.User), User.IsInRole(RoleNames.Trainer) || User.IsInRole(RoleNames.Dietitian), request, ct));
}
