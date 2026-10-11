using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SmartHealthFitness.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddRunningActivities : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "running_activities",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    started_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ended_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    duration_seconds = table.Column<int>(type: "integer", nullable: false),
                    distance_meters = table.Column<decimal>(type: "numeric(12,2)", precision: 12, scale: 2, nullable: false),
                    average_pace_seconds_per_km = table.Column<decimal>(type: "numeric(14,2)", precision: 14, scale: 2, nullable: true),
                    average_speed_kmh = table.Column<decimal>(type: "numeric(12,2)", precision: 12, scale: 2, nullable: false),
                    estimated_calories = table.Column<decimal>(type: "numeric(12,2)", precision: 12, scale: 2, nullable: true),
                    route_data = table.Column<string>(type: "jsonb", nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("pk_running_activities", x => x.id);
                    table.CheckConstraint("ck_running_activities_time", "ended_at >= started_at AND duration_seconds > 0 AND duration_seconds <= 86400");
                    table.CheckConstraint("ck_running_activities_values", "distance_meters >= 0 AND average_speed_kmh >= 0 AND (average_pace_seconds_per_km IS NULL OR average_pace_seconds_per_km >= 0)");
                    table.ForeignKey(
                        name: "FK_running_activities_users_user_id",
                        column: x => x.user_id,
                        principalTable: "users",
                        principalColumn: "id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "ix_running_activities_user_id_started_at",
                table: "running_activities",
                columns: new[] { "user_id", "started_at" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "running_activities");
        }
    }
}
