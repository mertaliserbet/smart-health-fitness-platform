using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SmartHealthFitness.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddMobileAssignmentReads : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "advisor_notes",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    advisor_id = table.Column<Guid>(type: "uuid", nullable: false),
                    title = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    content = table.Column<string>(type: "text", nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_advisor_notes", x => x.id);
                    table.ForeignKey(
                        name: "FK_advisor_notes_users_advisor_id",
                        column: x => x.advisor_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_advisor_notes_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "advisor_profiles",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    advisor_type = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    title = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    biography = table.Column<string>(type: "text", nullable: true),
                    specialization = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    is_active = table.Column<bool>(type: "boolean", nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_advisor_profiles", x => x.id);
                    table.CheckConstraint("ck_advisor_profiles_type", "advisor_type IN ('Trainer', 'Dietitian')");
                    table.ForeignKey(
                        name: "FK_advisor_profiles_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "exercises",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    description = table.Column<string>(type: "text", nullable: true),
                    instructions = table.Column<string>(type: "text", nullable: true),
                    video_url = table.Column<string>(type: "character varying(2048)", maxLength: 2048, nullable: true),
                    image_url = table.Column<string>(type: "character varying(2048)", maxLength: 2048, nullable: true),
                    is_active = table.Column<bool>(type: "boolean", nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_exercises", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "nutrition_goals",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    dietitian_id = table.Column<Guid>(type: "uuid", nullable: false),
                    daily_calories = table.Column<decimal>(type: "numeric(12,2)", precision: 12, scale: 2, nullable: false),
                    protein_grams = table.Column<decimal>(type: "numeric(12,2)", precision: 12, scale: 2, nullable: false),
                    carbohydrate_grams = table.Column<decimal>(type: "numeric(12,2)", precision: 12, scale: 2, nullable: false),
                    fat_grams = table.Column<decimal>(type: "numeric(12,2)", precision: 12, scale: 2, nullable: false),
                    water_ml = table.Column<decimal>(type: "numeric(12,2)", precision: 12, scale: 2, nullable: false),
                    start_date = table.Column<DateOnly>(type: "date", nullable: false),
                    end_date = table.Column<DateOnly>(type: "date", nullable: true),
                    is_active = table.Column<bool>(type: "boolean", nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_nutrition_goals", x => x.id);
                    table.CheckConstraint("ck_nutrition_goals_dates", "end_date IS NULL OR end_date >= start_date");
                    table.CheckConstraint("ck_nutrition_goals_targets", "daily_calories >= 0 AND protein_grams >= 0 AND carbohydrate_grams >= 0 AND fat_grams >= 0 AND water_ml >= 0");
                    table.ForeignKey(
                        name: "FK_nutrition_goals_users_dietitian_id",
                        column: x => x.dietitian_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_nutrition_goals_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "user_advisors",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    advisor_id = table.Column<Guid>(type: "uuid", nullable: false),
                    advisor_type = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    start_date = table.Column<DateOnly>(type: "date", nullable: false),
                    end_date = table.Column<DateOnly>(type: "date", nullable: true),
                    status = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_user_advisors", x => x.id);
                    table.CheckConstraint("ck_user_advisors_different_users", "user_id <> advisor_id");
                    table.CheckConstraint("ck_user_advisors_status_dates", "(status = 'Active' AND end_date IS NULL) OR (status IN ('Ended', 'Cancelled') AND end_date >= start_date AND end_date IS NOT NULL)");
                    table.CheckConstraint("ck_user_advisors_type", "advisor_type IN ('Trainer', 'Dietitian')");
                    table.ForeignKey(
                        name: "FK_user_advisors_users_advisor_id",
                        column: x => x.advisor_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_user_advisors_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "user_tasks",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    advisor_id = table.Column<Guid>(type: "uuid", nullable: false),
                    title = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    description = table.Column<string>(type: "text", nullable: true),
                    due_date = table.Column<DateOnly>(type: "date", nullable: true),
                    status = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    completed_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_user_tasks", x => x.id);
                    table.CheckConstraint("ck_user_tasks_status", "status IN ('Pending', 'InProgress', 'Completed', 'Cancelled')");
                    table.ForeignKey(
                        name: "FK_user_tasks_users_advisor_id",
                        column: x => x.advisor_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_user_tasks_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "workout_plans",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    trainer_id = table.Column<Guid>(type: "uuid", nullable: false),
                    name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    description = table.Column<string>(type: "text", nullable: true),
                    start_date = table.Column<DateOnly>(type: "date", nullable: false),
                    end_date = table.Column<DateOnly>(type: "date", nullable: true),
                    is_active = table.Column<bool>(type: "boolean", nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_workout_plans", x => x.id);
                    table.CheckConstraint("ck_workout_plans_dates", "end_date IS NULL OR end_date >= start_date");
                    table.ForeignKey(
                        name: "FK_workout_plans_users_trainer_id",
                        column: x => x.trainer_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_workout_plans_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "workout_days",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    workout_plan_id = table.Column<Guid>(type: "uuid", nullable: false),
                    name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    day_number = table.Column<int>(type: "integer", nullable: false),
                    weekday = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    description = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_workout_days", x => x.id);
                    table.CheckConstraint("ck_workout_days_number", "day_number > 0");
                    table.CheckConstraint("ck_workout_days_weekday", "weekday IN ('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday')");
                    table.ForeignKey(
                        name: "FK_workout_days_workout_plans_workout_plan_id",
                        column: x => x.workout_plan_id,
                        principalTable: "workout_plans",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "workout_exercises",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    workout_day_id = table.Column<Guid>(type: "uuid", nullable: false),
                    exercise_id = table.Column<Guid>(type: "uuid", nullable: false),
                    order = table.Column<int>(type: "integer", nullable: false),
                    sets = table.Column<int>(type: "integer", nullable: true),
                    reps = table.Column<int>(type: "integer", nullable: true),
                    duration_seconds = table.Column<int>(type: "integer", nullable: true),
                    rest_seconds = table.Column<int>(type: "integer", nullable: true),
                    weight_kg = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    notes = table.Column<string>(type: "text", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_workout_exercises", x => x.id);
                    table.CheckConstraint("ck_workout_exercises_order", "\"order\" > 0");
                    table.CheckConstraint("ck_workout_exercises_targets", "(sets IS NULL OR sets > 0) AND (reps IS NULL OR reps > 0) AND (duration_seconds IS NULL OR duration_seconds > 0) AND (rest_seconds IS NULL OR rest_seconds >= 0) AND (weight_kg IS NULL OR weight_kg >= 0)");
                    table.ForeignKey(
                        name: "FK_workout_exercises_exercises_exercise_id",
                        column: x => x.exercise_id,
                        principalTable: "exercises",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_workout_exercises_workout_days_workout_day_id",
                        column: x => x.workout_day_id,
                        principalTable: "workout_days",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_advisor_notes_advisor_id",
                table: "advisor_notes",
                column: "advisor_id");

            migrationBuilder.CreateIndex(
                name: "ix_advisor_notes_user_created",
                table: "advisor_notes",
                columns: new[] { "user_id", "created_at" });

            migrationBuilder.CreateIndex(
                name: "ux_advisor_profiles_user_id_advisor_type",
                table: "advisor_profiles",
                columns: new[] { "user_id", "advisor_type" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_nutrition_goals_dietitian_id",
                table: "nutrition_goals",
                column: "dietitian_id");

            migrationBuilder.CreateIndex(
                name: "ux_nutrition_goals_active_user",
                table: "nutrition_goals",
                column: "user_id",
                unique: true,
                filter: "is_active");

            migrationBuilder.CreateIndex(
                name: "IX_user_advisors_advisor_id",
                table: "user_advisors",
                column: "advisor_id");

            migrationBuilder.CreateIndex(
                name: "ux_user_advisors_active_user_advisor",
                table: "user_advisors",
                columns: new[] { "user_id", "advisor_id" },
                unique: true,
                filter: "status = 'Active'");

            migrationBuilder.CreateIndex(
                name: "IX_user_tasks_advisor_id",
                table: "user_tasks",
                column: "advisor_id");

            migrationBuilder.CreateIndex(
                name: "ix_user_tasks_user_created",
                table: "user_tasks",
                columns: new[] { "user_id", "created_at" });

            migrationBuilder.CreateIndex(
                name: "ux_workout_days_plan_number",
                table: "workout_days",
                columns: new[] { "workout_plan_id", "day_number" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "ux_workout_days_plan_weekday",
                table: "workout_days",
                columns: new[] { "workout_plan_id", "weekday" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_workout_exercises_exercise_id",
                table: "workout_exercises",
                column: "exercise_id");

            migrationBuilder.CreateIndex(
                name: "ux_workout_exercises_day_order",
                table: "workout_exercises",
                columns: new[] { "workout_day_id", "order" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_workout_plans_trainer_id",
                table: "workout_plans",
                column: "trainer_id");

            migrationBuilder.CreateIndex(
                name: "ix_workout_plans_user_start",
                table: "workout_plans",
                columns: new[] { "user_id", "start_date" });

            migrationBuilder.CreateIndex(
                name: "ux_workout_plans_active_user",
                table: "workout_plans",
                column: "user_id",
                unique: true,
                filter: "is_active");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "advisor_notes");

            migrationBuilder.DropTable(
                name: "advisor_profiles");

            migrationBuilder.DropTable(
                name: "nutrition_goals");

            migrationBuilder.DropTable(
                name: "user_advisors");

            migrationBuilder.DropTable(
                name: "user_tasks");

            migrationBuilder.DropTable(
                name: "workout_exercises");

            migrationBuilder.DropTable(
                name: "exercises");

            migrationBuilder.DropTable(
                name: "workout_days");

            migrationBuilder.DropTable(
                name: "workout_plans");
        }
    }
}
