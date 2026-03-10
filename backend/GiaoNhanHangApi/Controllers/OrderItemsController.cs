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
    public class OrderItemsController : ControllerBase
    {
        private readonly IDatabaseService _databaseService;
        private readonly AppDbContext _appDbContext;

        public OrderItemsController(IDatabaseService databaseService, AppDbContext appDbContext)
        {
            _databaseService = databaseService;
            _appDbContext = appDbContext;
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<OrderItem>>> GetAll([FromQuery] string? orderId)
        {
            try
            {
                var email = User.FindFirst(ClaimTypes.Email)?.Value ?? string.Empty;
                var userLogin = User.FindFirst(ClaimTypes.Name)?.Value ?? string.Empty;

                if (string.IsNullOrEmpty(email) || string.IsNullOrEmpty(userLogin))
                    return Unauthorized("Thông tin xác thực không hợp lệ");

                var dbContext = await _databaseService.GetDynamicDbContextAsync(email, userLogin, "");
                var query = dbContext.OrderItems.AsQueryable();
                
                if (!string.IsNullOrEmpty(orderId) && Guid.TryParse(orderId, out var orderGuid))
                    query = query.Where(oi => oi.OrderID == orderGuid);
                
                return await query.AsNoTracking().ToListAsync();
            }
            catch (Exception ex)
            {
                return BadRequest($"Không thể kết nối database: {ex.Message}");
            }
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<OrderItem>> GetById(Guid id)
        {
            try
            {
                var email = User.FindFirst(ClaimTypes.Email)?.Value;
                var userLogin = User.FindFirst(ClaimTypes.Name)?.Value;

                if (string.IsNullOrEmpty(email) || string.IsNullOrEmpty(userLogin))
                    return Unauthorized("Thông tin xác thực không hợp lệ");

                var dbContext = await _databaseService.GetDynamicDbContextAsync(email, userLogin, "");
                var entity = await dbContext.OrderItems.FindAsync(id);
                if (entity == null) return NotFound();
                return entity;
            }
            catch (Exception ex)
            {
                return BadRequest($"Không thể kết nối database: {ex.Message}");
            }
        }

        [HttpPost]
        public async Task<ActionResult<OrderItem>> Create(OrderItem input)
        {
            if (input.OrderID == Guid.Empty || string.IsNullOrWhiteSpace(input.ItemName))
                return BadRequest("OrderID and ItemName are required");

            try
            {
                var email = User.FindFirst(ClaimTypes.Email)?.Value;
                var userLogin = User.FindFirst(ClaimTypes.Name)?.Value;

                if (string.IsNullOrEmpty(email) || string.IsNullOrEmpty(userLogin))
                    return Unauthorized("Thông tin xác thực không hợp lệ");

                if (input.ItemID == Guid.Empty)
                    input.ItemID = Guid.NewGuid();

                var dbContext = await _databaseService.GetDynamicDbContextAsync(email, userLogin, "");
                dbContext.OrderItems.Add(input);
                await dbContext.SaveChangesAsync();
                return CreatedAtAction(nameof(GetById), new { id = input.ItemID }, input);
            }
            catch (Exception ex)
            {
                return BadRequest($"Không thể tạo order item: {ex.Message}");
            }
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> Update(Guid id, OrderItem input)
        {
            if (id != input.ItemID)
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
                return BadRequest($"Không thể cập nhật order item: {ex.Message}");
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
                var entity = await dbContext.OrderItems.FindAsync(id);
                if (entity == null) return NotFound();

                dbContext.OrderItems.Remove(entity);
                await dbContext.SaveChangesAsync();
                return NoContent();
            }
            catch (Exception ex)
            {
                return BadRequest($"Không thể xóa order item: {ex.Message}");
            }
        }
    }
}
