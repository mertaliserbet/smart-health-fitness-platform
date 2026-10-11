using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SmartHealthFitness.Api.Entities;

namespace SmartHealthFitness.Api.Data;

internal sealed class WorkoutSessionEntityConfiguration : IEntityTypeConfiguration<WorkoutSession>,
    IEntityTypeConfiguration<WorkoutLog>
{
    public void Configure(EntityTypeBuilder<WorkoutSession> builder)
    {
        builder.ToTable("workout_sessions", table =>
        {
            table.HasCheckConstraint("ck_workout_sessions_status", "status IN ('InProgress', 'Completed', 'Cancelled')");
            table.HasCheckConstraint("ck_workout_sessions_completion",
                "(status = 'Completed' AND completed_at IS NOT NULL AND completed_at >= started_at) OR (status <> 'Completed' AND completed_at IS NULL)");
        });
        builder.HasKey(session => session.Id).HasName("pk_workout_sessions");
        builder.Property(session => session.Status).HasConversion<string>().HasMaxLength(16);
        builder.Property(session => session.Notes).HasMaxLength(10000);
        builder.HasIndex(session => session.UserId).IsUnique().HasFilter("status = 'InProgress'")
            .HasDatabaseName("ux_workout_sessions_in_progress_user");
        builder.HasIndex(session => new { session.UserId, session.StartedAt, session.Id })
            .HasDatabaseName("ix_workout_sessions_user_history");
        builder.HasOne(session => session.User).WithMany().HasForeignKey(session => session.UserId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne(session => session.WorkoutPlan).WithMany().HasForeignKey(session => session.WorkoutPlanId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne(session => session.WorkoutDay).WithMany().HasForeignKey(session => session.WorkoutDayId).OnDelete(DeleteBehavior.Restrict);
    }

    public void Configure(EntityTypeBuilder<WorkoutLog> builder)
    {
        builder.ToTable("workout_logs", table => table.HasCheckConstraint("ck_workout_logs_values",
            "(completed_sets IS NULL OR completed_sets >= 0) AND (completed_reps IS NULL OR completed_reps >= 0) AND (duration_seconds IS NULL OR duration_seconds >= 0) AND (weight_kg IS NULL OR weight_kg >= 0)"));
        builder.HasKey(log => log.Id).HasName("pk_workout_logs");
        builder.Property(log => log.WeightKg).HasPrecision(10, 2);
        builder.Property(log => log.Notes).HasMaxLength(10000);
        builder.HasIndex(log => new { log.WorkoutSessionId, log.WorkoutExerciseId }).IsUnique()
            .HasDatabaseName("ux_workout_logs_session_exercise");
        builder.HasOne(log => log.WorkoutSession).WithMany(session => session.Logs)
            .HasForeignKey(log => log.WorkoutSessionId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne(log => log.WorkoutExercise).WithMany().HasForeignKey(log => log.WorkoutExerciseId).OnDelete(DeleteBehavior.Restrict);
    }
}
