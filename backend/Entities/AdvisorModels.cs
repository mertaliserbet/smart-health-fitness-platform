namespace SmartHealthFitness.Api.Entities;

public enum AdvisorType { Trainer, Dietitian }
public enum UserAdvisorStatus { Active, Ended, Cancelled }
public enum UserTaskStatus { Pending, InProgress, Completed, Cancelled }

public sealed class AdvisorProfile
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public AdvisorType AdvisorType { get; set; }
    public string? Title { get; set; }
    public string? Biography { get; set; }
    public string? Specialization { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAt { get; set; }
    public User User { get; set; } = null!;
}

public sealed class UserAdvisor
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public Guid AdvisorId { get; set; }
    public AdvisorType AdvisorType { get; set; }
    public DateOnly StartDate { get; set; }
    public DateOnly? EndDate { get; set; }
    public UserAdvisorStatus Status { get; set; } = UserAdvisorStatus.Active;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public User User { get; set; } = null!;
    public User Advisor { get; set; } = null!;
}

public sealed class AdvisorNote
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public Guid AdvisorId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Content { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAt { get; set; }
    public User User { get; set; } = null!;
    public User Advisor { get; set; } = null!;
}

public sealed class UserTask
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public Guid AdvisorId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }
    public DateOnly? DueDate { get; set; }
    public UserTaskStatus Status { get; set; } = UserTaskStatus.Pending;
    public DateTime? CompletedAt { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAt { get; set; }
    public User User { get; set; } = null!;
    public User Advisor { get; set; } = null!;
}
