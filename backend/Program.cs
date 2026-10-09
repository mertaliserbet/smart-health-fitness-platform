using SmartHealthFitness.Api.Configuration;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddBackendServices(builder.Configuration);

var app = builder.Build();

app.UseExceptionHandler();
app.UseStatusCodePages();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(options =>
        options.SwaggerEndpoint("/swagger/v1/swagger.json", "Smart Health Fitness API v1"));
    app.UseCors(ServiceCollectionExtensions.DevelopmentCorsPolicy);
}

app.MapControllers();

app.Run();
