using System.ComponentModel.DataAnnotations;
using System.Globalization;

namespace SmartHealthFitness.Api.Validation;

public sealed class TrackingValueAttribute(string minimum, string maximum) : ValidationAttribute
{
    public override bool IsValid(object? value) => value is null || value is decimal number &&
        number >= decimal.Parse(minimum, CultureInfo.InvariantCulture) &&
        number <= decimal.Parse(maximum, CultureInfo.InvariantCulture) &&
        ((decimal.GetBits(number)[3] >> 16) & 0xff) <= 2;

    public override string FormatErrorMessage(string name) =>
        $"{name}: {minimum}–{maximum} aralığında, en fazla iki ondalık basamaklı bir sayı girin.";
}

public sealed class PastOrPresentAttribute : ValidationAttribute
{
    public override bool IsValid(object? value) => value is null ||
        value is DateTimeOffset timestamp && timestamp <= DateTimeOffset.UtcNow;

    public override string FormatErrorMessage(string name) => "Kayıt zamanı gelecekte olamaz.";
}
