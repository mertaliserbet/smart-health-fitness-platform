using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SmartHealthFitness.Api.Entities;

namespace SmartHealthFitness.Api.Data;

internal sealed class AssignmentEntityConfiguration :
    IEntityTypeConfiguration<AdvisorProfile>, IEntityTypeConfiguration<UserAdvisor>,
    IEntityTypeConfiguration<AdvisorNote>, IEntityTypeConfiguration<UserTask>,
    IEntityTypeConfiguration<Exercise>, IEntityTypeConfiguration<WorkoutPlan>,
    IEntityTypeConfiguration<WorkoutDay>, IEntityTypeConfiguration<WorkoutExercise>,
    IEntityTypeConfiguration<NutritionGoal>
{
    public void Configure(EntityTypeBuilder<AdvisorProfile> builder)
    {
        builder.ToTable("advisor_profiles", table =>
            table.HasCheckConstraint("ck_advisor_profiles_type", "advisor_type IN ('Trainer', 'Dietitian')"));
        builder.HasKey(profile => profile.Id).HasName("pk_advisor_profiles");
        builder.Property(profile => profile.AdvisorType).HasConversion<string>().HasMaxLength(16);
        builder.Property(profile => profile.Title).HasMaxLength(200);
        builder.Property(profile => profile.Specialization).HasMaxLength(500);
        builder.HasIndex(profile => new { profile.UserId, profile.AdvisorType }).IsUnique()
            .HasDatabaseName("ux_advisor_profiles_user_id_advisor_type");
        builder.HasOne(profile => profile.User).WithMany().HasForeignKey(profile => profile.UserId)
            .OnDelete(DeleteBehavior.Restrict);
    }

    public void Configure(EntityTypeBuilder<UserAdvisor> builder)
    {
        builder.ToTable("user_advisors", table =>
        {
            table.HasCheckConstraint("ck_user_advisors_type", "advisor_type IN ('Trainer', 'Dietitian')");
            table.HasCheckConstraint("ck_user_advisors_status_dates",
                "(status = 'Active' AND end_date IS NULL) OR (status IN ('Ended', 'Cancelled') AND end_date >= start_date AND end_date IS NOT NULL)");
            table.HasCheckConstraint("ck_user_advisors_different_users", "user_id <> advisor_id");
        });
        builder.HasKey(relation => relation.Id).HasName("pk_user_advisors");
        builder.Property(relation => relation.AdvisorType).HasConversion<string>().HasMaxLength(16);
        builder.Property(relation => relation.Status).HasConversion<string>().HasMaxLength(16);
        builder.HasIndex(relation => new { relation.UserId, relation.AdvisorId }).IsUnique()
            .HasFilter("status = 'Active'").HasDatabaseName("ux_user_advisors_active_user_advisor");
        builder.HasOne(relation => relation.User).WithMany().HasForeignKey(relation => relation.UserId)
            .OnDelete(DeleteBehavior.Restrict);
        builder.HasOne(relation => relation.Advisor).WithMany().HasForeignKey(relation => relation.AdvisorId)
            .OnDelete(DeleteBehavior.Restrict);
    }

    public void Configure(EntityTypeBuilder<AdvisorNote> builder)
    {
        builder.ToTable("advisor_notes");
        builder.HasKey(note => note.Id).HasName("pk_advisor_notes");
        builder.Property(note => note.Title).HasMaxLength(200).IsRequired();
        builder.Property(note => note.Content).IsRequired();
        builder.HasIndex(note => new { note.UserId, note.CreatedAt }).HasDatabaseName("ix_advisor_notes_user_created");
        builder.HasOne(note => note.User).WithMany().HasForeignKey(note => note.UserId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne(note => note.Advisor).WithMany().HasForeignKey(note => note.AdvisorId).OnDelete(DeleteBehavior.Restrict);
    }

    public void Configure(EntityTypeBuilder<UserTask> builder)
    {
        builder.ToTable("user_tasks", table => table.HasCheckConstraint("ck_user_tasks_status",
            "status IN ('Pending', 'InProgress', 'Completed', 'Cancelled')"));
        builder.HasKey(task => task.Id).HasName("pk_user_tasks");
        builder.Property(task => task.Title).HasMaxLength(200).IsRequired();
        builder.Property(task => task.Status).HasConversion<string>().HasMaxLength(16);
        builder.HasIndex(task => new { task.UserId, task.CreatedAt }).HasDatabaseName("ix_user_tasks_user_created");
        builder.HasOne(task => task.User).WithMany().HasForeignKey(task => task.UserId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne(task => task.Advisor).WithMany().HasForeignKey(task => task.AdvisorId).OnDelete(DeleteBehavior.Restrict);
    }

    public void Configure(EntityTypeBuilder<Exercise> builder)
    {
        builder.ToTable("exercises");
        builder.HasKey(exercise => exercise.Id).HasName("pk_exercises");
        builder.Property(exercise => exercise.Name).HasMaxLength(200).IsRequired();
        builder.Property(exercise => exercise.ImageUrl).HasMaxLength(2048);
        builder.Property(exercise => exercise.VideoUrl).HasMaxLength(2048);
    }

    public void Configure(EntityTypeBuilder<WorkoutPlan> builder)
    {
        builder.ToTable("workout_plans", table =>
            table.HasCheckConstraint("ck_workout_plans_dates", "end_date IS NULL OR end_date >= start_date"));
        builder.HasKey(plan => plan.Id).HasName("pk_workout_plans");
        builder.Property(plan => plan.Name).HasMaxLength(200).IsRequired();
        builder.HasIndex(plan => plan.UserId).IsUnique().HasFilter("is_active")
            .HasDatabaseName("ux_workout_plans_active_user");
        builder.HasIndex(plan => new { plan.UserId, plan.StartDate }).HasDatabaseName("ix_workout_plans_user_start");
        builder.HasOne(plan => plan.User).WithMany().HasForeignKey(plan => plan.UserId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne(plan => plan.Trainer).WithMany().HasForeignKey(plan => plan.TrainerId).OnDelete(DeleteBehavior.Restrict);
    }

    public void Configure(EntityTypeBuilder<WorkoutDay> builder)
    {
        builder.ToTable("workout_days", table =>
        {
            table.HasCheckConstraint("ck_workout_days_weekday", "weekday IN ('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday')");
            table.HasCheckConstraint("ck_workout_days_number", "day_number > 0");
        });
        builder.HasKey(day => day.Id).HasName("pk_workout_days");
        builder.Property(day => day.Name).HasMaxLength(200).IsRequired();
        builder.Property(day => day.Weekday).HasConversion<string>().HasMaxLength(16);
        builder.HasIndex(day => new { day.WorkoutPlanId, day.Weekday }).IsUnique()
            .HasDatabaseName("ux_workout_days_plan_weekday");
        builder.HasIndex(day => new { day.WorkoutPlanId, day.DayNumber }).IsUnique()
            .HasDatabaseName("ux_workout_days_plan_number");
        builder.HasOne(day => day.WorkoutPlan).WithMany(plan => plan.Days)
            .HasForeignKey(day => day.WorkoutPlanId).OnDelete(DeleteBehavior.Cascade);
    }

    public void Configure(EntityTypeBuilder<WorkoutExercise> builder)
    {
        builder.ToTable("workout_exercises", table =>
        {
            table.HasCheckConstraint("ck_workout_exercises_order", "\"order\" > 0");
            table.HasCheckConstraint("ck_workout_exercises_targets",
                "(sets IS NULL OR sets > 0) AND (reps IS NULL OR reps > 0) AND (duration_seconds IS NULL OR duration_seconds > 0) AND (rest_seconds IS NULL OR rest_seconds >= 0) AND (weight_kg IS NULL OR weight_kg >= 0)");
        });
        builder.HasKey(exercise => exercise.Id).HasName("pk_workout_exercises");
        builder.Property(exercise => exercise.WeightKg).HasPrecision(10, 2);
        builder.HasIndex(exercise => new { exercise.WorkoutDayId, exercise.Order }).IsUnique()
            .HasDatabaseName("ux_workout_exercises_day_order");
        builder.HasOne(exercise => exercise.WorkoutDay).WithMany(day => day.Exercises)
            .HasForeignKey(exercise => exercise.WorkoutDayId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne(exercise => exercise.Exercise).WithMany().HasForeignKey(exercise => exercise.ExerciseId)
            .OnDelete(DeleteBehavior.Restrict);
    }

    public void Configure(EntityTypeBuilder<NutritionGoal> builder)
    {
        builder.ToTable("nutrition_goals", table =>
        {
            table.HasCheckConstraint("ck_nutrition_goals_dates", "end_date IS NULL OR end_date >= start_date");
            table.HasCheckConstraint("ck_nutrition_goals_targets",
                "daily_calories >= 0 AND protein_grams >= 0 AND carbohydrate_grams >= 0 AND fat_grams >= 0 AND water_ml >= 0");
        });
        builder.HasKey(goal => goal.Id).HasName("pk_nutrition_goals");
        foreach (var name in new[] { nameof(NutritionGoal.DailyCalories), nameof(NutritionGoal.ProteinGrams),
            nameof(NutritionGoal.CarbohydrateGrams), nameof(NutritionGoal.FatGrams), nameof(NutritionGoal.WaterMl) })
            builder.Property<decimal>(name).HasPrecision(12, 2);
        builder.HasIndex(goal => goal.UserId).IsUnique().HasFilter("is_active")
            .HasDatabaseName("ux_nutrition_goals_active_user");
        builder.HasOne(goal => goal.User).WithMany().HasForeignKey(goal => goal.UserId).OnDelete(DeleteBehavior.Restrict);
        builder.HasOne(goal => goal.Dietitian).WithMany().HasForeignKey(goal => goal.DietitianId).OnDelete(DeleteBehavior.Restrict);
    }
}
