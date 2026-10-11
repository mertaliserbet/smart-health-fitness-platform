using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SmartHealthFitness.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddManualNutritionRecords : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "nutrition_records",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    meal_type = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    calories = table.Column<decimal>(type: "numeric(12,2)", precision: 12, scale: 2, nullable: false),
                    protein_grams = table.Column<decimal>(type: "numeric(12,2)", precision: 12, scale: 2, nullable: false),
                    carbohydrate_grams = table.Column<decimal>(type: "numeric(12,2)", precision: 12, scale: 2, nullable: false),
                    fat_grams = table.Column<decimal>(type: "numeric(12,2)", precision: 12, scale: 2, nullable: false),
                    portion_description = table.Column<string>(type: "text", nullable: true),
                    source_type = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    food_recognition_log_id = table.Column<Guid>(type: "uuid", nullable: true),
                    consumed_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_nutrition_records", x => x.id);
                    table.CheckConstraint("ck_nutrition_records_manual_source", "source_type = 'Manual' AND food_recognition_log_id IS NULL");
                    table.CheckConstraint("ck_nutrition_records_meal_type", "meal_type IN ('Breakfast', 'Lunch', 'Dinner', 'Snack')");
                    table.CheckConstraint("ck_nutrition_records_values", "calories >= 0 AND protein_grams >= 0 AND carbohydrate_grams >= 0 AND fat_grams >= 0");
                    table.ForeignKey(
                        name: "FK_nutrition_records_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "ix_nutrition_records_user_id_consumed_at",
                table: "nutrition_records",
                columns: new[] { "user_id", "consumed_at" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "nutrition_records");
        }
    }
}
