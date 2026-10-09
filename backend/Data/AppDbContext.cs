using Microsoft.EntityFrameworkCore;

namespace SmartHealthFitness.Api.Data;

public sealed class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
}
