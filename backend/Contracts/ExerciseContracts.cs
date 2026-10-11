using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;
using SmartHealthFitness.Api.Entities;

namespace SmartHealthFitness.Api.Contracts;

public sealed record ExerciseResponse(Guid Id, string Name, string? Description, string? VideoUrl, string? ImageUrl)
{
    public static ExerciseResponse FromExercise(Exercise exercise) => new(
        exercise.Id, exercise.Name, exercise.Description, exercise.VideoUrl, exercise.ImageUrl);
}

public sealed record ExerciseDetailResponse(Guid Id, string Name, string? Description,
    string? Instructions, string? VideoUrl, string? ImageUrl, bool IsActive)
{
    public static ExerciseDetailResponse FromExercise(Exercise exercise) => new(
        exercise.Id, exercise.Name, exercise.Description, exercise.Instructions,
        exercise.VideoUrl, exercise.ImageUrl, exercise.IsActive);
}

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class CreateExerciseRequest
{
    [Required, StringLength(200)] public string Name { get; init; } = string.Empty;
    [StringLength(10000)] public string? Description { get; init; }
    [StringLength(20000)] public string? Instructions { get; init; }
    [StringLength(2048), Url] public string? VideoUrl { get; init; }
    [StringLength(2048), Url] public string? ImageUrl { get; init; }
    public bool IsActive { get; init; } = true;
}
