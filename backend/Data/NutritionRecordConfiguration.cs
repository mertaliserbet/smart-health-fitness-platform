using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SmartHealthFitness.Api.Entities;

namespace SmartHealthFitness.Api.Data;

internal sealed class NutritionRecordConfiguration : IEntityTypeConfiguration<NutritionRecord>
{
    public void Configure(EntityTypeBuilder<NutritionRecord> builder)
    {
        builder.ToTable("nutrition_records", table =>
        {
            table.HasCheckConstraint("ck_nutrition_records_meal_type", "meal_type IN ('Breakfast', 'Lunch', 'Dinner', 'Snack')");
            table.HasCheckConstraint("ck_nutrition_records_values", "calories >= 0 AND protein_grams >= 0 AND carbohydrate_grams >= 0 AND fat_grams >= 0");
            // FoodRecognitionLog is a future domain. Manual records cannot reference an absent AI log.
            table.HasCheckConstraint("ck_nutrition_records_manual_source", "source_type = 'Manual' AND food_recognition_log_id IS NULL");
        });
        builder.HasKey(record => record.Id).HasName("pk_nutrition_records");
        builder.Property(record => record.Name).HasMaxLength(200);
        builder.Property(record => record.MealType).HasConversion<string>().HasMaxLength(20);
        builder.Property(record => record.SourceType).HasConversion<string>().HasMaxLength(20);
        foreach (var property in new[] { nameof(NutritionRecord.Calories), nameof(NutritionRecord.ProteinGrams),
            nameof(NutritionRecord.CarbohydrateGrams), nameof(NutritionRecord.FatGrams) })
            builder.Property<decimal>(property).HasPrecision(12, 2);
        builder.HasIndex(record => new { record.UserId, record.ConsumedAt })
            .HasDatabaseName("ix_nutrition_records_user_id_consumed_at");
        builder.HasOne(record => record.User).WithMany().HasForeignKey(record => record.UserId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
