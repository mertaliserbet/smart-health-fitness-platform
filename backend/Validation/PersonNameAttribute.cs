using System.ComponentModel.DataAnnotations;
using System.Globalization;
using System.Text;

namespace SmartHealthFitness.Api.Validation;

public sealed class PersonNameAttribute : ValidationAttribute
{
    public PersonNameAttribute()
    {
        ErrorMessage = "Yalnızca harf, boşluk, tire ve apostrof kullanın.";
    }

    public override bool IsValid(object? value)
    {
        if (value is null) return true; // Required handles missing values.
        if (value is not string name) return false;

        var inNamePart = false;
        var previousWasSpace = false;
        // Runes include Unicode letters outside the UTF-16 basic multilingual plane.
        foreach (var rune in name.Trim(' ').EnumerateRunes())
        {
            if (Rune.IsLetter(rune))
            {
                inNamePart = true;
                previousWasSpace = false;
            }
            else if (Rune.GetUnicodeCategory(rune) is UnicodeCategory.NonSpacingMark
                or UnicodeCategory.SpacingCombiningMark or UnicodeCategory.EnclosingMark)
            {
                if (!inNamePart) return false;
            }
            else if (rune.Value == ' ')
            {
                if (!inNamePart && !previousWasSpace) return false;
                inNamePart = false;
                previousWasSpace = true;
            }
            else if (rune.Value is '-' or '\'' or '’')
            {
                if (!inNamePart) return false;
                inNamePart = false;
                previousWasSpace = false;
            }
            else return false;
        }
        return inNamePart;
    }
}
