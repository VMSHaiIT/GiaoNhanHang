using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using GiaoNhanHangApi.Data;
using GiaoNhanHangApi.Models;
using GiaoNhanHangApi.Services;
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;

namespace GiaoNhanHangApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class ReceiversController : ControllerBase
    {
        private readonly IDatabaseService _databaseService;
        private readonly AppDbContext _appDbContext;

        public ReceiversController(IDatabaseService databaseService, AppDbContext appDbContext)
        {
            _databaseService = databaseService;
            _appDbContext = appDbContext;
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<Receiver>>> GetAll([FromQuery] string? phone)
        {
            try
            {
                var email = User.FindFirst(ClaimTypes.Email)?.Value ?? string.Empty;
                var userLogin = User.FindFirst(ClaimTypes.Name)?.Value ?? string.Empty;

                if (string.IsNullOrEmpty(email) || string.IsNullOrEmpty(userLogin))
                    return Unauthorized("Thông tin xác thực không hợp lệ");

                var dbContext = await _databaseService.GetDynamicDbContextAsync(email, userLogin, "");
                IQueryable<Receiver> query = dbContext.Receivers.AsNoTracking();

                if (!string.IsNullOrWhiteSpace(phone) && phone.Trim().Length >= 3)
                {
                    var search = phone.Trim();
                    query = query.Where(r => r.Phone != null && r.Phone.Contains(search))
                        .Include(r => r.Branch).Include(r => r.DeliveryStaff)
                        .Take(20);
                }
                else
                {
                    query = query.Include(r => r.Branch).Include(r => r.DeliveryStaff);
                }

                var list = await query.ToListAsync();
                return list;
            }
            catch (Exception ex)
            {
                return BadRequest($"Không thể kết nối database: {ex.Message}");
            }
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<Receiver>> GetById(Guid id)
        {
            try
            {
                var email = User.FindFirst(ClaimTypes.Email)?.Value;
                var userLogin = User.FindFirst(ClaimTypes.Name)?.Value;

                if (string.IsNullOrEmpty(email) || string.IsNullOrEmpty(userLogin))
                    return Unauthorized("Thông tin xác thực không hợp lệ");

                var dbContext = await _databaseService.GetDynamicDbContextAsync(email, userLogin, "");
                var entity = await dbContext.Receivers.Include(r => r.Branch).Include(r => r.DeliveryStaff).FirstOrDefaultAsync(r => r.ReceiverID == id);
                if (entity == null) return NotFound();
                return entity;
            }
            catch (Exception ex)
            {
                return BadRequest($"Không thể kết nối database: {ex.Message}");
            }
        }

        [HttpPost]
        public async Task<ActionResult<Receiver>> Create(Receiver input)
        {
            if (string.IsNullOrWhiteSpace(input.Phone) || string.IsNullOrWhiteSpace(input.Name))
                return BadRequest("Phone and Name are required");

            try
            {
                var email = User.FindFirst(ClaimTypes.Email)?.Value;
                var userLogin = User.FindFirst(ClaimTypes.Name)?.Value;

                if (string.IsNullOrEmpty(email) || string.IsNullOrEmpty(userLogin))
                    return Unauthorized("Thông tin xác thực không hợp lệ");

                if (input.ReceiverID == Guid.Empty)
                    input.ReceiverID = Guid.NewGuid();

                var dbContext = await _databaseService.GetDynamicDbContextAsync(email, userLogin, "");
                dbContext.Receivers.Add(input);
                await dbContext.SaveChangesAsync();
                return CreatedAtAction(nameof(GetById), new { id = input.ReceiverID }, input);
            }
            catch (Exception ex)
            {
                return BadRequest($"Không thể tạo receiver: {ex.Message}");
            }
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> Update(Guid id, Receiver input)
        {
            if (id != input.ReceiverID)
                return BadRequest();

            try
            {
                var email = User.FindFirst(ClaimTypes.Email)?.Value;
                var userLogin = User.FindFirst(ClaimTypes.Name)?.Value;

                if (string.IsNullOrEmpty(email) || string.IsNullOrEmpty(userLogin))
                    return Unauthorized("Thông tin xác thực không hợp lệ");

                var dbContext = await _databaseService.GetDynamicDbContextAsync(email, userLogin, "");
                dbContext.Entry(input).State = EntityState.Modified;
                await dbContext.SaveChangesAsync();
                return NoContent();
            }
            catch (DbUpdateConcurrencyException)
            {
                return NotFound();
            }
            catch (Exception ex)
            {
                return BadRequest($"Không thể cập nhật receiver: {ex.Message}");
            }
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(Guid id)
        {
            try
            {
                var email = User.FindFirst(ClaimTypes.Email)?.Value;
                var userLogin = User.FindFirst(ClaimTypes.Name)?.Value;

                if (string.IsNullOrEmpty(email) || string.IsNullOrEmpty(userLogin))
                    return Unauthorized("Thông tin xác thực không hợp lệ");

                var dbContext = await _databaseService.GetDynamicDbContextAsync(email, userLogin, "");
                var entity = await dbContext.Receivers.FindAsync(id);
                if (entity == null) return NotFound();

                dbContext.Receivers.Remove(entity);
                await dbContext.SaveChangesAsync();
                return NoContent();
            }
            catch (Exception ex)
            {
                return BadRequest($"Không thể xóa receiver: {ex.Message}");
            }
        }
    }
}
