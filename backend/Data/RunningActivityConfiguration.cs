using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SmartHealthFitness.Api.Entities;

namespace SmartHealthFitness.Api.Data;

internal sealed class RunningActivityConfiguration : IEntityTypeConfiguration<RunningActivity>
{
    public void Configure(EntityTypeBuilder<RunningActivity> builder)
    {
        builder.ToTable("running_activities", table =>
        {
            table.HasCheckConstraint("ck_running_activities_time", "ended_at >= started_at AND duration_seconds > 0 AND duration_seconds <= 86400");
            table.HasCheckConstraint("ck_running_activities_values", "distance_meters >= 0 AND average_speed_kmh >= 0 AND (average_pace_seconds_per_km IS NULL OR average_pace_seconds_per_km >= 0)");
        });
        builder.HasKey(run => run.Id).HasName("pk_running_activities");
        builder.Property(run => run.DistanceMeters).HasPrecision(12, 2);
        builder.Property(run => run.AveragePaceSecondsPerKm).HasPrecision(14, 2);
        builder.Property(run => run.AverageSpeedKmh).HasPrecision(12, 2);
        builder.Property(run => run.EstimatedCalories).HasPrecision(12, 2);
        builder.Property(run => run.RouteData).HasColumnType("jsonb");
        builder.HasIndex(run => new { run.UserId, run.StartedAt }).HasDatabaseName("ix_running_activities_user_id_started_at");
        builder.HasOne(run => run.User).WithMany().HasForeignKey(run => run.UserId).OnDelete(DeleteBehavior.Cascade);
    }
}
