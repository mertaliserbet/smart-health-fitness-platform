using Microsoft.EntityFrameworkCore;
using SmartHealthFitness.Api.Contracts;
using SmartHealthFitness.Api.Data;
using SmartHealthFitness.Api.Entities;

namespace SmartHealthFitness.Api.Services;

public sealed class ExerciseService(AppDbContext dbContext)
{
    public Task<ExerciseResponse[]> GetExercisesAsync(string? search, CancellationToken cancellationToken)
    {
        var query = dbContext.Exercises.AsNoTracking().Where(exercise => exercise.IsActive);
        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim().ToLower();
            query = query.Where(exercise => exercise.Name.ToLower().Contains(term));
        }
        return query.OrderBy(exercise => exercise.Name).ThenBy(exercise => exercise.Id)
            .Select(exercise => new ExerciseResponse(exercise.Id, exercise.Name, exercise.Description,
                exercise.Instructions, exercise.VideoUrl, exercise.ImageUrl)).ToArrayAsync(cancellationToken);
    }

    public async Task<ExerciseDetailResponse> GetExerciseAsync(Guid id, bool isAdmin, CancellationToken cancellationToken)
    {
        var exercise = await dbContext.Exercises.AsNoTracking()
            .SingleOrDefaultAsync(exercise => exercise.Id == id && (exercise.IsActive || isAdmin), cancellationToken);
        return exercise is null ? throw AssignmentException.NotFound("Egzersiz bulunamadı.")
            : ExerciseDetailResponse.FromExercise(exercise);
    }

    public async Task<ExerciseDetailResponse> SaveExerciseAsync(Guid? id, CreateExerciseRequest request,
        CancellationToken cancellationToken)
    {
        var exercise = id is null ? new Exercise() : await dbContext.Exercises
            .SingleOrDefaultAsync(exercise => exercise.Id == id, cancellationToken)
            ?? throw AssignmentException.NotFound("Egzersiz bulunamadı.");
        exercise.Name = request.Name.Trim();
        exercise.Description = request.Description?.Trim();
        exercise.Instructions = request.Instructions?.Trim();
        exercise.VideoUrl = request.VideoUrl?.Trim();
        exercise.ImageUrl = request.ImageUrl?.Trim();
        exercise.IsActive = request.IsActive;
        if (id is null) dbContext.Exercises.Add(exercise);
        else exercise.UpdatedAt = DateTime.UtcNow;
        await dbContext.SaveChangesAsync(cancellationToken);
        return ExerciseDetailResponse.FromExercise(exercise);
    }
}
