using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SmartHealthFitness.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddWeightRecordsAndBodyMeasurements : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "body_measurements",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    chest_cm = table.Column<decimal>(type: "numeric(6,2)", precision: 6, scale: 2, nullable: true),
                    waist_cm = table.Column<decimal>(type: "numeric(6,2)", precision: 6, scale: 2, nullable: true),
                    hip_cm = table.Column<decimal>(type: "numeric(6,2)", precision: 6, scale: 2, nullable: true),
                    arm_cm = table.Column<decimal>(type: "numeric(6,2)", precision: 6, scale: 2, nullable: true),
                    thigh_cm = table.Column<decimal>(type: "numeric(6,2)", precision: 6, scale: 2, nullable: true),
                    body_fat_percentage = table.Column<decimal>(type: "numeric(6,2)", precision: 6, scale: 2, nullable: true),
                    recorded_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_body_measurements", x => x.id);
                    table.CheckConstraint("ck_body_measurements_arm_cm", "arm_cm IS NULL OR (arm_cm > 0 AND arm_cm <= 1000)");
                    table.CheckConstraint("ck_body_measurements_body_fat_percentage", "body_fat_percentage IS NULL OR (body_fat_percentage >= 0 AND body_fat_percentage <= 100)");
                    table.CheckConstraint("ck_body_measurements_chest_cm", "chest_cm IS NULL OR (chest_cm > 0 AND chest_cm <= 1000)");
                    table.CheckConstraint("ck_body_measurements_has_value", "chest_cm IS NOT NULL OR waist_cm IS NOT NULL OR hip_cm IS NOT NULL OR arm_cm IS NOT NULL OR thigh_cm IS NOT NULL OR body_fat_percentage IS NOT NULL");
                    table.CheckConstraint("ck_body_measurements_hip_cm", "hip_cm IS NULL OR (hip_cm > 0 AND hip_cm <= 1000)");
                    table.CheckConstraint("ck_body_measurements_thigh_cm", "thigh_cm IS NULL OR (thigh_cm > 0 AND thigh_cm <= 1000)");
                    table.CheckConstraint("ck_body_measurements_waist_cm", "waist_cm IS NULL OR (waist_cm > 0 AND waist_cm <= 1000)");
                    table.ForeignKey(
                        name: "FK_body_measurements_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "weight_records",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    weight_kg = table.Column<decimal>(type: "numeric(6,2)", precision: 6, scale: 2, nullable: false),
                    recorded_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_weight_records", x => x.id);
                    table.CheckConstraint("ck_weight_records_weight_kg", "weight_kg > 0 AND weight_kg <= 1000");
                    table.ForeignKey(
                        name: "FK_weight_records_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "ix_body_measurements_user_id_recorded_at",
                table: "body_measurements",
                columns: new[] { "user_id", "recorded_at" });

            migrationBuilder.CreateIndex(
                name: "ix_weight_records_user_id_recorded_at",
                table: "weight_records",
                columns: new[] { "user_id", "recorded_at" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "body_measurements");

            migrationBuilder.DropTable(
                name: "weight_records");
        }
    }
}
