using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;

namespace SmartHealthFitness.Api.Services;

public sealed class AssignmentException(int status, string message,
    Dictionary<string, string[]>? errors = null) : Exception(message)
{
    public int Status { get; } = status;
    public Dictionary<string, string[]>? Errors { get; } = errors;

    public static AssignmentException NotFound(string message = "Kayıt bulunamadı.") => new(404, message);
    public static AssignmentException Conflict(string message) => new(409, message);
    public static AssignmentException Invalid(string field, string message) => new(400,
        "Validation failed", new Dictionary<string, string[]> { [field] = [message] });
}

public sealed class AssignmentExceptionFilter : IExceptionFilter
{
    public void OnException(ExceptionContext context)
    {
        if (context.Exception is not AssignmentException error) return;
        ProblemDetails problem = error.Errors is null
            ? new ProblemDetails { Title = error.Message, Detail = error.Message }
            : new ValidationProblemDetails(error.Errors) { Title = error.Message };
        problem.Status = error.Status;
        problem.Instance = context.HttpContext.Request.Path;
        context.Result = new ObjectResult(problem) { StatusCode = error.Status,
            ContentTypes = { "application/problem+json" } };
        context.ExceptionHandled = true;
    }
}
