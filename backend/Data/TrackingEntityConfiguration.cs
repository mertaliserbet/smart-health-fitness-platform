using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SmartHealthFitness.Api.Entities;

namespace SmartHealthFitness.Api.Data;

internal sealed class TrackingEntityConfiguration :
    IEntityTypeConfiguration<WeightRecord>, IEntityTypeConfiguration<BodyMeasurement>
{
    public void Configure(EntityTypeBuilder<WeightRecord> builder)
    {
        builder.ToTable("weight_records", table =>
            table.HasCheckConstraint("ck_weight_records_weight_kg", "weight_kg > 0 AND weight_kg <= 1000"));
        builder.HasKey(record => record.Id).HasName("pk_weight_records");
        builder.Property(record => record.WeightKg).HasPrecision(6, 2);
        builder.HasIndex(record => new { record.UserId, record.RecordedAt })
            .HasDatabaseName("ix_weight_records_user_id_recorded_at");
        builder.HasOne(record => record.User).WithMany()
            .HasForeignKey(record => record.UserId).OnDelete(DeleteBehavior.Cascade);
    }

    public void Configure(EntityTypeBuilder<BodyMeasurement> builder)
    {
        builder.ToTable("body_measurements", table =>
        {
            foreach (var column in new[] { "chest_cm", "waist_cm", "hip_cm", "arm_cm", "thigh_cm" })
                table.HasCheckConstraint($"ck_body_measurements_{column}",
                    $"{column} IS NULL OR ({column} > 0 AND {column} <= 1000)");
            table.HasCheckConstraint("ck_body_measurements_body_fat_percentage",
                "body_fat_percentage IS NULL OR (body_fat_percentage >= 0 AND body_fat_percentage <= 100)");
            table.HasCheckConstraint("ck_body_measurements_has_value",
                "chest_cm IS NOT NULL OR waist_cm IS NOT NULL OR hip_cm IS NOT NULL OR arm_cm IS NOT NULL OR thigh_cm IS NOT NULL OR body_fat_percentage IS NOT NULL");
        });
        builder.HasKey(record => record.Id).HasName("pk_body_measurements");
        foreach (var property in new[] { nameof(BodyMeasurement.ChestCm), nameof(BodyMeasurement.WaistCm),
            nameof(BodyMeasurement.HipCm), nameof(BodyMeasurement.ArmCm), nameof(BodyMeasurement.ThighCm),
            nameof(BodyMeasurement.BodyFatPercentage) })
            builder.Property<decimal?>(property).HasPrecision(6, 2);
        builder.HasIndex(record => new { record.UserId, record.RecordedAt })
            .HasDatabaseName("ix_body_measurements_user_id_recorded_at");
        builder.HasOne(record => record.User).WithMany()
            .HasForeignKey(record => record.UserId).OnDelete(DeleteBehavior.Cascade);
    }
}
