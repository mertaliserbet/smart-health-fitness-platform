using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace SmartHealthFitness.Api.Contracts;

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class CreateAdvisorNoteRequest
{
    [Required, StringLength(200)] public string Title { get; init; } = string.Empty;
    [Required] public string Content { get; init; } = string.Empty;
}

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class CreateUserTaskRequest
{
    [Required, StringLength(200)] public string Title { get; init; } = string.Empty;
    public string? Description { get; init; }
    public DateOnly? DueDate { get; init; }
}

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class UpdateTaskStatusRequest
{
    [Required, RegularExpression("Pending|InProgress|Completed|Cancelled")]
    public string Status { get; init; } = string.Empty;
}
