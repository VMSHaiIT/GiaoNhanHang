using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using GiaoNhanHangApi.Data;
using GiaoNhanHangApi.Hubs;
using GiaoNhanHangApi.Models;
using GiaoNhanHangApi.Services;
using System.Security.Claims;

namespace GiaoNhanHangApi.Controllers
{
    /// <summary>
    /// REST API hỗ trợ module tracking vị trí staff.
    /// SignalR Hub (/locationHub) là kênh chính cho real-time.
    /// Controller này phục vụ:
    ///   - Lấy vị trí mới nhất của tất cả staff đang active
    ///   - Lấy lịch sử vị trí theo trip
    ///   - Staff gửi vị trí (fallback khi không có SignalR)
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class LocationController : ControllerBase
    {
        private readonly IDatabaseService _databaseService;

        public LocationController(IDatabaseService databaseService)
        {
            _databaseService = databaseService;
        }

        // ──────────────────────────────────────────────
        // GET api/location/active
        // Trả về vị trí mới nhất của tất cả staff đang active
        // (dùng in-memory cache của LocationHub)
        // ──────────────────────────────────────────────
        [HttpGet("active")]
        public IActionResult GetActiveLocations()
        {
            // Lấy từ in-memory cache của hub
            var snapshot = LocationHubCache.GetAll();
            return Ok(snapshot);
        }

        // ──────────────────────────────────────────────
        // GET api/location/trip/{tripId}
        // Lịch sử vị trí theo chuyến (giới hạn 500 bản ghi mới nhất)
        // ──────────────────────────────────────────────
        [HttpGet("trip/{tripId}")]
        public async Task<IActionResult> GetTripHistory(Guid tripId, [FromQuery] int limit = 500)
        {
            try
            {
                var email = User.FindFirst(ClaimTypes.Email)?.Value ?? string.Empty;
                var userLogin = User.FindFirst(ClaimTypes.Name)?.Value ?? string.Empty;

                if (string.IsNullOrEmpty(email))
                    return Unauthorized();

                var dbContext = await _databaseService.GetDynamicDbContextAsync(email, userLogin, "");

                var history = await dbContext.StaffLocations
                    .Where(l => l.TripID == tripId)
                    .OrderByDescending(l => l.Timestamp)
                    .Take(limit)
                    .Select(l => new
                    {
                        l.LocationID,
                        l.StaffID,
                        staffName = l.Staff != null ? l.Staff.Name : string.Empty,
                        l.TripID,
                        l.Latitude,
                        l.Longitude,
                        l.SpeedKmh,
                        l.Heading,
                        l.Timestamp,
                        l.IsActive,
                    })
                    .AsNoTracking()
                    .ToListAsync();

                return Ok(history);
            }
            catch (Exception ex)
            {
                return BadRequest($"Lỗi lấy lịch sử vị trí: {ex.Message}");
            }
        }

        // ──────────────────────────────────────────────
        // GET api/location/staff/{staffId}/latest
        // Vị trí mới nhất của 1 staff (fallback REST)
        // ──────────────────────────────────────────────
        [HttpGet("staff/{staffId}/latest")]
        public async Task<IActionResult> GetLatestByStaff(Guid staffId)
        {
            try
            {
                var email = User.FindFirst(ClaimTypes.Email)?.Value ?? string.Empty;
                var userLogin = User.FindFirst(ClaimTypes.Name)?.Value ?? string.Empty;

                if (string.IsNullOrEmpty(email))
                    return Unauthorized();

                var dbContext = await _databaseService.GetDynamicDbContextAsync(email, userLogin, "");

                var latest = await dbContext.StaffLocations
                    .Where(l => l.StaffID == staffId)
                    .OrderByDescending(l => l.Timestamp)
                    .FirstOrDefaultAsync();

                if (latest == null) return NotFound();
                return Ok(latest);
            }
            catch (Exception ex)
            {
                return BadRequest($"Lỗi lấy vị trí staff: {ex.Message}");
            }
        }

        // ──────────────────────────────────────────────
        // POST api/location/update  (REST fallback khi SignalR không dùng được)
        // ──────────────────────────────────────────────
        [HttpPost("update")]
        public async Task<IActionResult> UpdateLocation([FromBody] StaffLocationUpdateRequest req)
        {
            try
            {
                var email = User.FindFirst(ClaimTypes.Email)?.Value ?? string.Empty;
                var userLogin = User.FindFirst(ClaimTypes.Name)?.Value ?? string.Empty;

                if (string.IsNullOrEmpty(email))
                    return Unauthorized();

                var dbContext = await _databaseService.GetDynamicDbContextAsync(email, userLogin, "");

                var entity = new StaffLocation
                {
                    LocationID = Guid.NewGuid(),
                    StaffID = req.StaffID,
                    TripID = req.TripID,
                    Latitude = req.Latitude,
                    Longitude = req.Longitude,
                    SpeedKmh = req.SpeedKmh,
                    Heading = req.Heading,
                    Timestamp = DateTime.UtcNow,
                    IsActive = true,
                };

                dbContext.StaffLocations.Add(entity);
                await dbContext.SaveChangesAsync();

                // Cập nhật cache in-memory
                LocationHubCache.Set(new Hubs.StaffLocationDto
                {
                    StaffID = req.StaffID.ToString(),
                    TripID = req.TripID.ToString(),
                    Latitude = req.Latitude,
                    Longitude = req.Longitude,
                    SpeedKmh = req.SpeedKmh,
                    Heading = req.Heading,
                    Timestamp = entity.Timestamp,
                });

                return Ok(new { message = "Cập nhật vị trí thành công" });
            }
            catch (Exception ex)
            {
                return BadRequest($"Lỗi cập nhật vị trí: {ex.Message}");
            }
        }

        // ──────────────────────────────────────────────
        // POST api/location/stop
        // Staff dừng chia sẻ vị trí
        // ──────────────────────────────────────────────
        [HttpPost("stop")]
        public async Task<IActionResult> StopSharing([FromBody] StaffLocationStopRequest req)
        {
            try
            {
                var email = User.FindFirst(ClaimTypes.Email)?.Value ?? string.Empty;
                var userLogin = User.FindFirst(ClaimTypes.Name)?.Value ?? string.Empty;

                if (string.IsNullOrEmpty(email))
                    return Unauthorized();

                var dbContext = await _databaseService.GetDynamicDbContextAsync(email, userLogin, "");

                // Đánh dấu IsActive = false cho các bản ghi của chuyến này
                var records = await dbContext.StaffLocations
                    .Where(l => l.StaffID == req.StaffID && l.TripID == req.TripID && l.IsActive)
                    .ToListAsync();

                foreach (var r in records)
                    r.IsActive = false;

                await dbContext.SaveChangesAsync();

                LocationHubCache.Remove(req.StaffID.ToString());

                return Ok(new { message = "Đã dừng chia sẻ vị trí" });
            }
            catch (Exception ex)
            {
                return BadRequest($"Lỗi dừng chia sẻ: {ex.Message}");
            }
        }
    }

    // ──────────────────────────────────────────────
    // Request DTOs
    // ──────────────────────────────────────────────
    public class StaffLocationUpdateRequest
    {
        public Guid StaffID { get; set; }
        public Guid TripID { get; set; }
        public double Latitude { get; set; }
        public double Longitude { get; set; }
        public double? SpeedKmh { get; set; }
        public double? Heading { get; set; }
    }

    public class StaffLocationStopRequest
    {
        public Guid StaffID { get; set; }
        public Guid TripID { get; set; }
    }

    // ──────────────────────────────────────────────
    // Static cache dùng chung giữa Hub và Controller
    // ──────────────────────────────────────────────
    public static class LocationHubCache
    {
        private static readonly Dictionary<string, Hubs.StaffLocationDto> _cache = new();
        private static readonly object _lock = new();

        public static void Set(Hubs.StaffLocationDto dto)
        {
            lock (_lock) { _cache[dto.StaffID] = dto; }
        }

        public static void Remove(string staffId)
        {
            lock (_lock) { _cache.Remove(staffId); }
        }

        public static List<Hubs.StaffLocationDto> GetAll()
        {
            lock (_lock) { return _cache.Values.ToList(); }
        }
    }
}
