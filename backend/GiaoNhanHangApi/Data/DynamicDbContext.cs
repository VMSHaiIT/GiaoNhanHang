using Microsoft.EntityFrameworkCore;
using GiaoNhanHangApi.Models;

namespace GiaoNhanHangApi.Data
{
    public class DynamicDbContext : DbContext
    {
        private readonly string _connectionString;

        public DynamicDbContext(string connectionString)
        {
            _connectionString = connectionString;
        }

        protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
        {
            if (!optionsBuilder.IsConfigured)
            {
                optionsBuilder.UseSqlServer(_connectionString, sqlOptions =>
                {
                    sqlOptions.EnableRetryOnFailure(
                        maxRetryCount: 5,
                        maxRetryDelay: TimeSpan.FromSeconds(30),
                        errorNumbersToAdd: null);
                    sqlOptions.CommandTimeout(60);
                });

                // Enable SQL logging for debugging
                optionsBuilder.LogTo(Console.WriteLine, Microsoft.Extensions.Logging.LogLevel.Information);
            }
        }

        // Các bảng cho business logic
        public DbSet<Order> Orders => Set<Order>();
        public DbSet<Sender> Senders => Set<Sender>();
        public DbSet<Receiver> Receivers => Set<Receiver>();
        public DbSet<OrderItem> OrderItems => Set<OrderItem>();
        public DbSet<Payment> Payments => Set<Payment>();
        public DbSet<Models.Route> Routes => Set<Models.Route>();
        public DbSet<Trip> Trips => Set<Trip>();
        public DbSet<Branch> Branches => Set<Branch>();
        public DbSet<Vehicle> Vehicles => Set<Vehicle>();
        public DbSet<Staff> Staff => Set<Staff>();
        public DbSet<StaffLocation> StaffLocations => Set<StaffLocation>();

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            // Orders
            modelBuilder.Entity<Order>(entity =>
            {
                entity.HasKey(e => e.OrderID);
                entity.Property(e => e.OrderDate).IsRequired();
                entity.Property(e => e.ExpectedDeliveryDate).IsRequired();
                entity.Property(e => e.OrderType).IsRequired().HasMaxLength(100);
                entity.Property(e => e.TotalValue).HasColumnType("decimal(18,2)");
                entity.Property(e => e.TotalWeight).HasColumnType("decimal(18,2)");
                entity.Property(e => e.TotalAmount).HasColumnType("decimal(18,2)");
                entity.Property(e => e.Status).HasMaxLength(50);
                entity.Property(e => e.CreatedDate).HasDefaultValueSql("GETDATE()");
                entity.Property(e => e.CreatedBy).HasMaxLength(450);
                
                entity.HasOne(e => e.Sender)
                    .WithMany(s => s.Orders)
                    .HasForeignKey(e => e.SenderID)
                    .OnDelete(DeleteBehavior.SetNull);
                    
                entity.HasOne(e => e.Receiver)
                    .WithMany(r => r.Orders)
                    .HasForeignKey(e => e.ReceiverID)
                    .OnDelete(DeleteBehavior.SetNull);
                    
                entity.HasOne(e => e.Route)
                    .WithMany()
                    .HasForeignKey(e => e.RouteID)
                    .OnDelete(DeleteBehavior.SetNull);
                    
                entity.HasOne(e => e.Trip)
                    .WithMany()
                    .HasForeignKey(e => e.TripID)
                    .OnDelete(DeleteBehavior.SetNull);
            });

            // Senders
            modelBuilder.Entity<Sender>(entity =>
            {
                entity.HasKey(e => e.SenderID);
                entity.Property(e => e.Phone).IsRequired().HasMaxLength(50);
                entity.Property(e => e.Name).IsRequired().HasMaxLength(200);
                entity.Property(e => e.Address).HasMaxLength(500);
                entity.Property(e => e.District).HasMaxLength(100);
                
                entity.HasOne(e => e.Branch)
                    .WithMany(b => b.Senders)
                    .HasForeignKey(e => e.BranchID)
                    .OnDelete(DeleteBehavior.SetNull);
                    
                entity.HasOne(e => e.PickupStaff)
                    .WithMany(s => s.PickupSenders)
                    .HasForeignKey(e => e.PickupStaffID)
                    .OnDelete(DeleteBehavior.SetNull);
            });

            // Receivers
            modelBuilder.Entity<Receiver>(entity =>
            {
                entity.HasKey(e => e.ReceiverID);
                entity.Property(e => e.Phone).IsRequired().HasMaxLength(50);
                entity.Property(e => e.Name).IsRequired().HasMaxLength(200);
                entity.Property(e => e.Address).HasMaxLength(500);
                entity.Property(e => e.District).HasMaxLength(100);
                
                entity.HasOne(e => e.Branch)
                    .WithMany(b => b.Receivers)
                    .HasForeignKey(e => e.BranchID)
                    .OnDelete(DeleteBehavior.SetNull);
                    
                entity.HasOne(e => e.DeliveryStaff)
                    .WithMany(s => s.DeliveryReceivers)
                    .HasForeignKey(e => e.DeliveryStaffID)
                    .OnDelete(DeleteBehavior.SetNull);
            });

            // OrderItems
            modelBuilder.Entity<OrderItem>(entity =>
            {
                entity.HasKey(e => e.ItemID);
                entity.Property(e => e.ItemName).IsRequired().HasMaxLength(200);
                entity.Property(e => e.Unit).HasMaxLength(50);
                entity.Property(e => e.Weight).HasColumnType("decimal(18,2)");
                entity.Property(e => e.Price).HasColumnType("decimal(18,2)");
                entity.Property(e => e.Amount).HasColumnType("decimal(18,2)");
                
                entity.HasOne(e => e.Order)
                    .WithMany(o => o.OrderItems)
                    .HasForeignKey(e => e.OrderID)
                    .OnDelete(DeleteBehavior.Cascade);
            });

            // Payments
            modelBuilder.Entity<Payment>(entity =>
            {
                entity.HasKey(e => e.PaymentID);
                entity.Property(e => e.ShippingFee).HasColumnType("decimal(18,2)");
                entity.Property(e => e.CODAmount).HasColumnType("decimal(18,2)");
                entity.Property(e => e.CODFee).HasColumnType("decimal(18,2)");
                entity.Property(e => e.TotalPayment).HasColumnType("decimal(18,2)");
                entity.Property(e => e.PaymentMethod).HasMaxLength(50);
                
                entity.HasOne(e => e.Order)
                    .WithOne(o => o.Payment)
                    .HasForeignKey<Payment>(e => e.OrderID)
                    .OnDelete(DeleteBehavior.Cascade);
            });

            // Routes
            modelBuilder.Entity<Models.Route>(entity =>
            {
                entity.HasKey(e => e.RouteID);
                entity.Property(e => e.RouteName).IsRequired().HasMaxLength(200);
                entity.Property(e => e.Origin).HasMaxLength(200);
                entity.Property(e => e.Destination).HasMaxLength(200);
                entity.Property(e => e.TransportType).HasMaxLength(50);
            });

            // Trips
            modelBuilder.Entity<Trip>(entity =>
            {
                entity.HasKey(e => e.TripID);
                entity.Property(e => e.Status).HasMaxLength(50);
                
                entity.HasOne(e => e.Route)
                    .WithMany(r => r.Trips)
                    .HasForeignKey(e => e.RouteID)
                    .OnDelete(DeleteBehavior.Restrict);
                    
                entity.HasOne(e => e.Vehicle)
                    .WithMany(v => v.Trips)
                    .HasForeignKey(e => e.VehicleID)
                    .OnDelete(DeleteBehavior.SetNull);
                    
                entity.HasOne(e => e.Driver)
                    .WithMany(s => s.DriverTrips)
                    .HasForeignKey(e => e.DriverID)
                    .OnDelete(DeleteBehavior.SetNull);
            });

            // Branches
            modelBuilder.Entity<Branch>(entity =>
            {
                entity.HasKey(e => e.BranchID);
                entity.Property(e => e.BranchName).IsRequired().HasMaxLength(200);
            });

            // Vehicles
            modelBuilder.Entity<Vehicle>(entity =>
            {
                entity.HasKey(e => e.VehicleID);
                entity.Property(e => e.VehicleName).IsRequired().HasMaxLength(200);
            });

            // Staff
            modelBuilder.Entity<Staff>(entity =>
            {
                entity.HasKey(e => e.StaffID);
                entity.Property(e => e.Name).IsRequired().HasMaxLength(200);
                entity.Property(e => e.Phone).HasMaxLength(50);
            });

            // StaffLocations
            modelBuilder.Entity<StaffLocation>(entity =>
            {
                entity.HasKey(e => e.LocationID);
                entity.Property(e => e.Latitude).HasColumnType("decimal(10,7)");
                entity.Property(e => e.Longitude).HasColumnType("decimal(10,7)");
                entity.Property(e => e.SpeedKmh).HasColumnType("decimal(6,2)");
                entity.Property(e => e.Heading).HasColumnType("decimal(6,2)");
                entity.Property(e => e.Timestamp).HasDefaultValueSql("GETUTCDATE()");

                entity.HasOne(e => e.Staff)
                    .WithMany()
                    .HasForeignKey(e => e.StaffID)
                    .OnDelete(DeleteBehavior.Cascade);

                entity.HasOne(e => e.Trip)
                    .WithMany()
                    .HasForeignKey(e => e.TripID)
                    .OnDelete(DeleteBehavior.Cascade);

                // Index tăng tốc query theo staff + trip
                entity.HasIndex(e => new { e.StaffID, e.TripID, e.Timestamp });
            });
        }
    }
}
