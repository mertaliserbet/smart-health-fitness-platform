using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using SmartHealthFitness.Api.Services;

namespace SmartHealthFitness.Api.Controllers;

// Limited to advisor management controllers; shared auth/error middleware is unchanged.
public sealed class AssignmentExceptionFilter : IExceptionFilter
{
    public void OnException(ExceptionContext context)
    {
        if (context.Exception is not AssignmentRequestException exception) return;
        ProblemDetails problem = exception.Errors is null ? new ProblemDetails()
            : new ValidationProblemDetails(exception.Errors);
        problem.Status = exception.StatusCode;
        problem.Title = exception.Message;
        problem.Instance = context.HttpContext.Request.Path;
        context.Result = new ObjectResult(problem) { StatusCode = exception.StatusCode,
            ContentTypes = { "application/problem+json" } };
        context.ExceptionHandled = true;
    }
}
