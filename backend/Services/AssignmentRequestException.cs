namespace SmartHealthFitness.Api.Services;

public sealed class AssignmentRequestException(int statusCode, string message,
    IDictionary<string, string[]>? errors = null) : Exception(message)
{
    public int StatusCode { get; } = statusCode;
    public IDictionary<string, string[]>? Errors { get; } = errors;

    public static AssignmentRequestException NotFound(string message = "Danışan veya aktif ilişki bulunamadı.") => new(404, message);
    public static AssignmentRequestException Conflict(string message) => new(409, message);
    public static AssignmentRequestException Invalid(string field, string message) => new(400,
        "Validation failed", new Dictionary<string, string[]> { [field] = [message] });
}
