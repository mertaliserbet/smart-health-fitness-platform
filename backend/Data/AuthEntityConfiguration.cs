using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using SmartHealthFitness.Api.Entities;

namespace SmartHealthFitness.Api.Data;

internal sealed class AuthEntityConfiguration :
    IEntityTypeConfiguration<User>, IEntityTypeConfiguration<Role>,
    IEntityTypeConfiguration<UserRole>, IEntityTypeConfiguration<RefreshToken>
{
    public void Configure(EntityTypeBuilder<User> builder)
    {
        builder.ToTable("users");
        builder.HasKey(user => user.Id).HasName("pk_users");
        builder.Property(user => user.FirstName).HasMaxLength(100).IsRequired();
        builder.Property(user => user.LastName).HasMaxLength(100).IsRequired();
        builder.Property(user => user.Email).HasMaxLength(254).IsRequired();
        builder.Property(user => user.PasswordHash).HasMaxLength(512).IsRequired();
        builder.Property(user => user.PhoneNumber).HasMaxLength(32);
        builder.Property(user => user.Gender).HasMaxLength(32);
        builder.Property(user => user.HeightCm).HasPrecision(5, 2);
        builder.HasIndex(user => user.Email).IsUnique().HasDatabaseName("ux_users_email");
    }

    public void Configure(EntityTypeBuilder<Role> builder)
    {
        builder.ToTable("roles");
        builder.HasKey(role => role.Id).HasName("pk_roles");
        builder.Property(role => role.Name).HasMaxLength(32).IsRequired();
        builder.HasIndex(role => role.Name).IsUnique().HasDatabaseName("ux_roles_name");
        builder.HasData(
            new Role { Id = Guid.Parse("00000000-0000-0000-0000-000000000001"), Name = RoleNames.User },
            new Role { Id = Guid.Parse("00000000-0000-0000-0000-000000000002"), Name = RoleNames.Trainer },
            new Role { Id = Guid.Parse("00000000-0000-0000-0000-000000000003"), Name = RoleNames.Dietitian },
            new Role { Id = Guid.Parse("00000000-0000-0000-0000-000000000004"), Name = RoleNames.Admin });
    }

    public void Configure(EntityTypeBuilder<UserRole> builder)
    {
        builder.ToTable("user_roles");
        builder.HasKey(userRole => userRole.Id).HasName("pk_user_roles");
        builder.HasIndex(userRole => new { userRole.UserId, userRole.RoleId })
            .IsUnique().HasDatabaseName("ux_user_roles_user_id_role_id");
        builder.HasOne(userRole => userRole.User).WithMany(user => user.UserRoles)
            .HasForeignKey(userRole => userRole.UserId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne(userRole => userRole.Role).WithMany()
            .HasForeignKey(userRole => userRole.RoleId).OnDelete(DeleteBehavior.Restrict);
    }

    public void Configure(EntityTypeBuilder<RefreshToken> builder)
    {
        builder.ToTable("refresh_tokens");
        builder.HasKey(token => token.Id).HasName("pk_refresh_tokens");
        builder.Property(token => token.TokenHash).HasMaxLength(64).IsRequired();
        builder.HasIndex(token => token.TokenHash).IsUnique().HasDatabaseName("ux_refresh_tokens_token_hash");
        builder.HasOne(token => token.User).WithMany()
            .HasForeignKey(token => token.UserId).OnDelete(DeleteBehavior.Cascade);
    }
}
