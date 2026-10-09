namespace SmartHealthFitness.Api.Entities;

public sealed class Role
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
}

public static class RoleNames
{
    public const string User = "User";
    public const string Trainer = "Trainer";
    public const string Dietitian = "Dietitian";
    public const string Admin = "Admin";
}
