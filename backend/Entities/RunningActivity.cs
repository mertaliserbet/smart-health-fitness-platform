namespace SmartHealthFitness.Api.Entities;

public sealed class RunningActivity
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public DateTime StartedAt { get; set; }
    public DateTime EndedAt { get; set; }
    public int DurationSeconds { get; set; }
    public decimal DistanceMeters { get; set; }
    public decimal? AveragePaceSecondsPerKm { get; set; }
    public decimal AverageSpeedKmh { get; set; }
    public decimal? EstimatedCalories { get; set; }
    public string RouteData { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public User User { get; set; } = null!;
}
