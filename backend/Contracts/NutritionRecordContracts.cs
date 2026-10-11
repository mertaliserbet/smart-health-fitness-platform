using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;
using SmartHealthFitness.Api.Entities;
using SmartHealthFitness.Api.Validation;

namespace SmartHealthFitness.Api.Contracts;

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed class CreateNutritionRecordRequest : IValidatableObject
{
    [Required, RegularExpression("Breakfast|Lunch|Dinner|Snack")]
    public string MealType { get; init; } = string.Empty;
    [Required, StringLength(200)] public string Name { get; init; } = string.Empty;
    [Required, TrackingValue("0", "9999999999.99")] public decimal? Calories { get; init; }
    [Required, TrackingValue("0", "9999999999.99")] public decimal? ProteinGrams { get; init; }
    [Required, TrackingValue("0", "9999999999.99")] public decimal? CarbohydrateGrams { get; init; }
    [Required, TrackingValue("0", "9999999999.99")] public decimal? FatGrams { get; init; }
    public string? PortionDescription { get; init; }
    [Required, RegularExpression("Manual")] public string SourceType { get; init; } = "Manual";
    public Guid? FoodRecognitionLogId { get; init; }
    [Required, PastOrPresent] public DateTimeOffset? ConsumedAt { get; init; }

    public IEnumerable<ValidationResult> Validate(ValidationContext context)
    {
        if (FoodRecognitionLogId is not null)
            yield return new("Manuel kayıt AI analizine bağlanamaz.", ["foodRecognitionLogId"]);
    }
}

public sealed record NutritionRecordResponse(Guid Id, Guid UserId, MealType MealType, string Name,
    decimal Calories, decimal ProteinGrams, decimal CarbohydrateGrams, decimal FatGrams,
    string? PortionDescription, NutritionSourceType SourceType, Guid? FoodRecognitionLogId,
    DateTime ConsumedAt, DateTime CreatedAt)
{
    public static NutritionRecordResponse FromRecord(NutritionRecord record) => new(record.Id, record.UserId,
        record.MealType, record.Name, record.Calories, record.ProteinGrams, record.CarbohydrateGrams,
        record.FatGrams, record.PortionDescription, record.SourceType, record.FoodRecognitionLogId,
        record.ConsumedAt, record.CreatedAt);
}

public sealed record NutritionDailySummaryResponse(DateOnly Date, int RecordCount, decimal ConsumedCalories,
    decimal ConsumedProteinGrams, decimal ConsumedCarbohydrateGrams, decimal ConsumedFatGrams,
    NutritionGoalResponse? Goal);
