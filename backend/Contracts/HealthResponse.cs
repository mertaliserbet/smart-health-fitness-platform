namespace SmartHealthFitness.Api.Contracts;

public sealed record HealthResponse(string Status, string Database, DateTime CheckedAt);
