using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SmartHealthFitness.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddWorkoutSessionsAndLogs : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "workout_sessions",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    workout_plan_id = table.Column<Guid>(type: "uuid", nullable: false),
                    workout_day_id = table.Column<Guid>(type: "uuid", nullable: false),
                    started_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    completed_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    status = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    notes = table.Column<string>(type: "character varying(10000)", maxLength: 10000, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_workout_sessions", x => x.id);
                    table.CheckConstraint("ck_workout_sessions_completion", "(status = 'Completed' AND completed_at IS NOT NULL AND completed_at >= started_at) OR (status <> 'Completed' AND completed_at IS NULL)");
                    table.CheckConstraint("ck_workout_sessions_status", "status IN ('InProgress', 'Completed', 'Cancelled')");
                    table.ForeignKey(
                        name: "FK_workout_sessions_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_workout_sessions_workout_days_workout_day_id",
                        column: x => x.workout_day_id,
                        principalTable: "workout_days",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_workout_sessions_workout_plans_workout_plan_id",
                        column: x => x.workout_plan_id,
                        principalTable: "workout_plans",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "workout_logs",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    workout_session_id = table.Column<Guid>(type: "uuid", nullable: false),
                    workout_exercise_id = table.Column<Guid>(type: "uuid", nullable: false),
                    completed_sets = table.Column<int>(type: "integer", nullable: true),
                    completed_reps = table.Column<int>(type: "integer", nullable: true),
                    weight_kg = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    duration_seconds = table.Column<int>(type: "integer", nullable: true),
                    is_completed = table.Column<bool>(type: "boolean", nullable: false),
                    notes = table.Column<string>(type: "character varying(10000)", maxLength: 10000, nullable: true),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_workout_logs", x => x.id);
                    table.CheckConstraint("ck_workout_logs_values", "(completed_sets IS NULL OR completed_sets >= 0) AND (completed_reps IS NULL OR completed_reps >= 0) AND (duration_seconds IS NULL OR duration_seconds >= 0) AND (weight_kg IS NULL OR weight_kg >= 0)");
                    table.ForeignKey(
                        name: "FK_workout_logs_workout_exercises_workout_exercise_id",
                        column: x => x.workout_exercise_id,
                        principalTable: "workout_exercises",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_workout_logs_workout_sessions_workout_session_id",
                        column: x => x.workout_session_id,
                        principalTable: "workout_sessions",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_workout_logs_workout_exercise_id",
                table: "workout_logs",
                column: "workout_exercise_id");

            migrationBuilder.CreateIndex(
                name: "ux_workout_logs_session_exercise",
                table: "workout_logs",
                columns: new[] { "workout_session_id", "workout_exercise_id" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_workout_sessions_workout_day_id",
                table: "workout_sessions",
                column: "workout_day_id");

            migrationBuilder.CreateIndex(
                name: "IX_workout_sessions_workout_plan_id",
                table: "workout_sessions",
                column: "workout_plan_id");

            migrationBuilder.CreateIndex(
                name: "ix_workout_sessions_user_history",
                table: "workout_sessions",
                columns: new[] { "user_id", "started_at", "id" });

            migrationBuilder.CreateIndex(
                name: "ux_workout_sessions_in_progress_user",
                table: "workout_sessions",
                column: "user_id",
                unique: true,
                filter: "status = 'InProgress'");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "workout_logs");

            migrationBuilder.DropTable(
                name: "workout_sessions");
        }
    }
}
