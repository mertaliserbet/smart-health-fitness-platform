namespace SmartHealthFitness.Api.Entities;

public enum MealType { Breakfast, Lunch, Dinner, Snack }
public enum NutritionSourceType { Manual, AI }

public sealed class NutritionRecord
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public MealType MealType { get; set; }
    public string Name { get; set; } = string.Empty;
    public decimal Calories { get; set; }
    public decimal ProteinGrams { get; set; }
    public decimal CarbohydrateGrams { get; set; }
    public decimal FatGrams { get; set; }
    public string? PortionDescription { get; set; }
    public NutritionSourceType SourceType { get; set; } = NutritionSourceType.Manual;
    public Guid? FoodRecognitionLogId { get; set; }
    public DateTime ConsumedAt { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public User User { get; set; } = null!;
}
