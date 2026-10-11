using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;
using SmartHealthFitness.Api.Validation;

namespace SmartHealthFitness.Api.Contracts;

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class CreateNutritionGoalRequest : IValidatableObject
{
    [Required, TrackingValue("0", "9999999999.99")] public decimal? DailyCalories { get; init; }
    [Required, TrackingValue("0", "9999999999.99")] public decimal? ProteinGrams { get; init; }
    [Required, TrackingValue("0", "9999999999.99")] public decimal? CarbohydrateGrams { get; init; }
    [Required, TrackingValue("0", "9999999999.99")] public decimal? FatGrams { get; init; }
    [Required, TrackingValue("0", "9999999999.99")] public decimal? WaterMl { get; init; }
    [Required] public DateOnly? StartDate { get; init; }
    public DateOnly? EndDate { get; init; }

    public IEnumerable<ValidationResult> Validate(ValidationContext context)
    {
        if (EndDate < StartDate) yield return new("Bitiş tarihi başlangıçtan önce olamaz.", ["endDate"]);
    }
}
