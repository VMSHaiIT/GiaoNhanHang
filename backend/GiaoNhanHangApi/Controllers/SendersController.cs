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
    public class SendersController : ControllerBase
    {
        private readonly IDatabaseService _databaseService;
        private readonly AppDbContext _appDbContext;

        public SendersController(IDatabaseService databaseService, AppDbContext appDbContext)
        {
            _databaseService = databaseService;
            _appDbContext = appDbContext;
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<Sender>>> GetAll([FromQuery] string? phone)
        {
            try
            {
                var email = User.FindFirst(ClaimTypes.Email)?.Value ?? string.Empty;
                var userLogin = User.FindFirst(ClaimTypes.Name)?.Value ?? string.Empty;

                if (string.IsNullOrEmpty(email) || string.IsNullOrEmpty(userLogin))
                    return Unauthorized("Thông tin xác thực không hợp lệ");

                var dbContext = await _databaseService.GetDynamicDbContextAsync(email, userLogin, "");
                IQueryable<Sender> query = dbContext.Senders.AsNoTracking();

                if (!string.IsNullOrWhiteSpace(phone) && phone.Trim().Length >= 3)
                {
                    var search = phone.Trim();
                    query = query.Where(s => s.Phone != null && s.Phone.Contains(search)).Take(20);
                }
                else
                {
                    query = query.Include(s => s.Branch).Include(s => s.PickupStaff);
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
        public async Task<ActionResult<Sender>> GetById(Guid id)
        {
            try
            {
                var email = User.FindFirst(ClaimTypes.Email)?.Value;
                var userLogin = User.FindFirst(ClaimTypes.Name)?.Value;

                if (string.IsNullOrEmpty(email) || string.IsNullOrEmpty(userLogin))
                    return Unauthorized("Thông tin xác thực không hợp lệ");

                var dbContext = await _databaseService.GetDynamicDbContextAsync(email, userLogin, "");
                var entity = await dbContext.Senders.Include(s => s.Branch).Include(s => s.PickupStaff).FirstOrDefaultAsync(s => s.SenderID == id);
                if (entity == null) return NotFound();
                return entity;
            }
            catch (Exception ex)
            {
                return BadRequest($"Không thể kết nối database: {ex.Message}");
            }
        }

        [HttpPost]
        public async Task<ActionResult<Sender>> Create(Sender input)
        {
            if (string.IsNullOrWhiteSpace(input.Phone) || string.IsNullOrWhiteSpace(input.Name))
                return BadRequest("Phone and Name are required");

            try
            {
                var email = User.FindFirst(ClaimTypes.Email)?.Value;
                var userLogin = User.FindFirst(ClaimTypes.Name)?.Value;

                if (string.IsNullOrEmpty(email) || string.IsNullOrEmpty(userLogin))
                    return Unauthorized("Thông tin xác thực không hợp lệ");

                if (input.SenderID == Guid.Empty)
                    input.SenderID = Guid.NewGuid();

                var dbContext = await _databaseService.GetDynamicDbContextAsync(email, userLogin, "");
                dbContext.Senders.Add(input);
                await dbContext.SaveChangesAsync();
                return CreatedAtAction(nameof(GetById), new { id = input.SenderID }, input);
            }
            catch (Exception ex)
            {
                return BadRequest($"Không thể tạo sender: {ex.Message}");
            }
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> Update(Guid id, Sender input)
        {
            if (id != input.SenderID)
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
                return BadRequest($"Không thể cập nhật sender: {ex.Message}");
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
                var entity = await dbContext.Senders.FindAsync(id);
                if (entity == null) return NotFound();

                dbContext.Senders.Remove(entity);
                await dbContext.SaveChangesAsync();
                return NoContent();
            }
            catch (Exception ex)
            {
                return BadRequest($"Không thể xóa sender: {ex.Message}");
            }
        }
    }
}
