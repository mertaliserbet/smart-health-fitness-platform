using System.Globalization;
using System.IdentityModel.Tokens.Jwt;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartHealthFitness.Api.Contracts;
using SmartHealthFitness.Api.Entities;
using SmartHealthFitness.Api.Services;

namespace SmartHealthFitness.Api.Controllers;

[ApiController, Route("api/users/me/nutrition-records")]
[Authorize(Policy = RoleNames.User)]
[ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
public sealed class NutritionRecordsController(NutritionService nutrition) : ControllerBase
{
    private Guid UserId => Guid.Parse(User.FindFirst(JwtRegisteredClaimNames.Sub)!.Value);

    [HttpPost]
    [ProducesResponseType<NutritionRecordResponse>(StatusCodes.Status201Created)]
    public async Task<ActionResult<NutritionRecordResponse>> CreateRecord(CreateNutritionRecordRequest request,
        CancellationToken ct) => Created("/api/users/me/nutrition-records", await nutrition.CreateRecordAsync(UserId, request, ct));

    [HttpGet]
    public async Task<ActionResult<NutritionRecordResponse[]>> GetRecords([FromQuery] string? date,
        [FromQuery] DateTimeOffset? from, [FromQuery] DateTimeOffset? to, [FromQuery] string? mealType, CancellationToken ct)
    {
        MealType? meal = null;
        if (mealType is not null)
        {
            if (!Enum.TryParse<MealType>(mealType, out var parsed) || parsed.ToString() != mealType || !Enum.IsDefined(parsed))
                ModelState.AddModelError("mealType", "Breakfast, Lunch, Dinner veya Snack seçin.");
            else meal = parsed;
        }
        var day = ParseDate(date);
        var range = ResolveRange(day, from, to);
        if (!ModelState.IsValid) return ValidationProblem(ModelState);
        return Ok(await nutrition.GetRecordsAsync(UserId, range.From, range.To, meal, ct));
    }

    [HttpGet("daily-summary")]
    public async Task<ActionResult<NutritionDailySummaryResponse>> GetDailySummary([FromQuery] string? date,
        [FromQuery] DateTimeOffset? from, [FromQuery] DateTimeOffset? to, CancellationToken ct)
    {
        var day = ParseDate(date) ?? DateOnly.FromDateTime(DateTime.UtcNow);
        var range = ResolveRange(day, from, to);
        if (!ModelState.IsValid) return ValidationProblem(ModelState);
        return Ok(await nutrition.GetDailySummaryAsync(UserId, day, range.From!.Value, range.To!.Value, ct));
    }

    private DateOnly? ParseDate(string? date)
    {
        if (date is null) return null;
        if (DateOnly.TryParseExact(date, "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out var day)
            && day != DateOnly.MaxValue) return day;
        ModelState.AddModelError("date", "Geçerli YYYY-MM-DD tarihi girin (9999-12-31 hariç).");
        return null;
    }

    private (DateTime? From, DateTime? To) ResolveRange(DateOnly? date, DateTimeOffset? from, DateTimeOffset? to)
    {
        if (date is not null)
        {
            var day = date.Value;
            if (from is null && to is null)
            {
                var midnight = day.ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc);
                return (midnight, midnight.AddDays(1));
            }
            // Explicit midnight offsets preserve the actual local day, including DST transitions.
            if (from is null || to is null || from.Value.TimeOfDay != TimeSpan.Zero || to.Value.TimeOfDay != TimeSpan.Zero
                || DateOnly.FromDateTime(from.Value.Date) != day || DateOnly.FromDateTime(to.Value.Date) != day.AddDays(1))
                ModelState.AddModelError("date", "from/to seçili günün ve sonraki günün offset içeren gece yarıları olmalı.");
        }
        if (from is not null && to is not null && from >= to)
            ModelState.AddModelError("to", "Bitiş zamanı başlangıçtan sonra olmalı; bitiş sınırı dahil değildir.");
        return (from?.UtcDateTime, to?.UtcDateTime);
    }
}
