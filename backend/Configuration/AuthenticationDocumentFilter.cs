using Microsoft.AspNetCore.Authorization;
using Microsoft.OpenApi;
using Swashbuckle.AspNetCore.SwaggerGen;

namespace SmartHealthFitness.Api.Configuration;

public sealed class AuthenticationDocumentFilter : IDocumentFilter
{
    public void Apply(OpenApiDocument document, DocumentFilterContext context)
    {
        foreach (var description in context.ApiDescriptions)
        {
            if (description.ActionDescriptor.EndpointMetadata.OfType<IAllowAnonymous>().Any())
            {
                continue;
            }

            var path = "/" + description.RelativePath?.Split('?')[0];
            if (!document.Paths.TryGetValue(path, out var pathItem))
            {
                continue;
            }

            var operation = pathItem.Operations?.FirstOrDefault(pair =>
                string.Equals(pair.Key.ToString(), description.HttpMethod, StringComparison.OrdinalIgnoreCase)).Value;
            if (operation is not null)
            {
                operation.Security = [new OpenApiSecurityRequirement
                {
                    [new OpenApiSecuritySchemeReference("Bearer", document)] = []
                }];
            }
        }
    }
}
