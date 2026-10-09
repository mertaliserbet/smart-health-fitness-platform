using System.Text.Json.Serialization;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Mvc.ModelBinding.Metadata;
using SmartHealthFitness.Api.Data;

namespace SmartHealthFitness.Api.Configuration;

public static class ServiceCollectionExtensions
{
    public const string DevelopmentCorsPolicy = "Development";

    public static IServiceCollection AddBackendServices(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        var connectionString = configuration["DATABASE_CONNECTION_STRING"];
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            connectionString = configuration.GetConnectionString("DefaultConnection");
        }

        if (string.IsNullOrWhiteSpace(connectionString))
        {
            throw new InvalidOperationException(
                "Set DATABASE_CONNECTION_STRING or ConnectionStrings:DefaultConnection before starting the API.");
        }

        services.AddDbContext<AppDbContext>(options => options.UseNpgsql(connectionString));
        services.AddBackendAuthentication(configuration);

        services.AddControllers(options =>
            options.ModelMetadataDetailsProviders.Add(new SystemTextJsonValidationMetadataProvider()))
            .AddJsonOptions(options =>
            options.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter()));
        services.AddProblemDetails();
        services.AddEndpointsApiExplorer();
        services.AddSwaggerGen(options =>
        {
            options.SupportNonNullableReferenceTypes();
            options.AddSecurityDefinition("Bearer", new Microsoft.OpenApi.OpenApiSecurityScheme
            {
                Type = Microsoft.OpenApi.SecuritySchemeType.Http,
                Scheme = "bearer",
                BearerFormat = "JWT"
            });
            options.DocumentFilter<AuthenticationDocumentFilter>();
            options.SwaggerDoc("v1", new()
            {
                Title = "Yapay Zekâ Destekli Sağlık ve Fitness Platformu API",
                Version = "v1"
            });
        });

        var allowedOrigins = configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];
        services.AddCors(options => options.AddPolicy(DevelopmentCorsPolicy, policy =>
        {
            if (allowedOrigins.Length > 0)
            {
                policy.WithOrigins(allowedOrigins).AllowAnyHeader().AllowAnyMethod();
            }
        }));

        return services;
    }
}
