using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using GiaoNhanHangApi.Models;
using GiaoNhanHangApi.Services;
using GiaoNhanHangApi.Data;
using GiaoNhanHangApi.Controllers;
using System.Security.Claims;

namespace GiaoNhanHangApi.Hubs
{
    /// <summary>
    /// SignalR Hub phát vị trí thời gian thực của staff.
    /// 
    /// Client methods (server gọi → client nhận):
    ///   - "ReceiveLocation"  : (StaffLocationDto) cập nhật vị trí 1 staff
    ///   - "StaffStopped"     : (string staffId, string tripId) staff dừng chia sẻ
    ///   - "ActiveStaffs"     : (List&lt;StaffLocationDto&gt;) danh sách staff đang active (khi join)
    ///
    /// Server methods (client gọi lên):
    ///   - SendLocation       : staff gửi vị trí mới
    ///   - StopSharing        : staff dừng chia sẻ
    ///   - JoinTripGroup      : admin theo dõi 1 chuyến
    ///   - JoinAdminRoom      : admin theo dõi tất cả
    /// </summary>
    [Authorize]
    public class LocationHub : Hub
    {
        private readonly IServiceScopeFactory _scopeFactory;

        public LocationHub(IServiceScopeFactory scopeFactory)
        {
            _scopeFactory = scopeFactory;
        }

        // ──────────────────────────────────────────────
        // Staff gửi vị trí mới
        // ──────────────────────────────────────────────
        public async Task SendLocation(StaffLocationDto dto)
        {
            var email = Context.User?.FindFirst(ClaimTypes.Email)?.Value ?? string.Empty;
            var userLogin = Context.User?.FindFirst(ClaimTypes.Name)?.Value ?? string.Empty;

            if (string.IsNullOrEmpty(email)) return;

            dto.Timestamp = DateTime.UtcNow;

            // Cập nhật cache in-memory dùng chung
            LocationHubCache.Set(dto);

            // Lưu vào DB không block hub — tạo scope mới để tránh disposed context
            _ = Task.Run(async () =>
            {
                try
                {
                    if (!Guid.TryParse(dto.StaffID, out var staffGuid)) return;
                    if (!Guid.TryParse(dto.TripID, out var tripGuid)) return;

                    // IServiceScopeFactory là singleton — an toàn để dùng trong background task
                    using var scope = _scopeFactory.CreateScope();
                    var dbService = scope.ServiceProvider.GetRequiredService<IDatabaseService>();
                    var dbContext = await dbService.GetDynamicDbContextAsync(email, userLogin, "");

                    var entity = new StaffLocation
                    {
                        LocationID = Guid.NewGuid(),
                        StaffID = staffGuid,
                        TripID = tripGuid,
                        Latitude = dto.Latitude,
                        Longitude = dto.Longitude,
                        SpeedKmh = dto.SpeedKmh,
                        Heading = dto.Heading,
                        Timestamp = dto.Timestamp,
                        IsActive = true,
                    };
                    dbContext.StaffLocations.Add(entity);
                    await dbContext.SaveChangesAsync();
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"[LocationHub] SaveLocation error: {ex.Message}");
                }
            });

            // Broadcast đến admin room
            await Clients.Group("admin_room").SendAsync("ReceiveLocation", dto);

            // Broadcast đến group theo dõi chuyến này
            await Clients.Group($"trip_{dto.TripID}").SendAsync("ReceiveLocation", dto);
        }

        // ──────────────────────────────────────────────
        // Staff dừng chia sẻ vị trí
        // ──────────────────────────────────────────────
        public async Task StopSharing(string staffId, string tripId)
        {
            LocationHubCache.Remove(staffId);

            await Clients.Group("admin_room").SendAsync("StaffStopped", staffId, tripId);
            await Clients.Group($"trip_{tripId}").SendAsync("StaffStopped", staffId, tripId);
        }

        // ──────────────────────────────────────────────
        // Admin join room để nhận tất cả cập nhật
        // ──────────────────────────────────────────────
        public async Task JoinAdminRoom()
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, "admin_room");

            // Gửi snapshot danh sách active ngay khi join
            var snapshot = LocationHubCache.GetAll();
            await Clients.Caller.SendAsync("ActiveStaffs", snapshot);
        }

        // ──────────────────────────────────────────────
        // Theo dõi 1 chuyến cụ thể
        // ──────────────────────────────────────────────
        public async Task JoinTripGroup(string tripId)
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, $"trip_{tripId}");

            // Gửi vị trí mới nhất của staff trong chuyến đó
            var snapshot = LocationHubCache.GetAll()
                .Where(l => l.TripID == tripId)
                .ToList();
            await Clients.Caller.SendAsync("ActiveStaffs", snapshot);
        }

        public override Task OnDisconnectedAsync(Exception? exception)
        {
            return base.OnDisconnectedAsync(exception);
        }
    }

    // ──────────────────────────────────────────────
    // DTO truyền qua SignalR (nhẹ, không có nav props)
    // ──────────────────────────────────────────────
    public class StaffLocationDto
    {
        public string StaffID { get; set; } = string.Empty;
        public string StaffName { get; set; } = string.Empty;
        public string TripID { get; set; } = string.Empty;
        public double Latitude { get; set; }
        public double Longitude { get; set; }
        public double? SpeedKmh { get; set; }
        public double? Heading { get; set; }
        public DateTime Timestamp { get; set; }
    }
}
