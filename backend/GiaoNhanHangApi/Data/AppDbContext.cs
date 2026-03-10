using Microsoft.EntityFrameworkCore;
using GiaoNhanHangApi.Models;

namespace GiaoNhanHangApi.Data
{
    public class AppDbContext : DbContext
    {
        public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

        // Chỉ giữ bảng Users trong database GiaoNhanHangAdmin
        public DbSet<User> Users => Set<User>();

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            // Cấu hình bảng User
            modelBuilder.Entity<User>(entity =>
            {
                entity.HasKey(e => e.Email);
                entity.Property(e => e.Email).IsRequired().HasMaxLength(255);
                entity.Property(e => e.UserLogin).IsRequired().HasMaxLength(255);
                entity.Property(e => e.PasswordLogin).IsRequired().HasMaxLength(255);
                entity.Property(e => e.CreatedAt).HasDefaultValueSql("GETDATE()");
            });
        }
    }
}
