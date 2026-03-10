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
    public class OrdersController : ControllerBase
    {
        private readonly IDatabaseService _databaseService;
        private readonly AppDbContext _appDbContext;

        public OrdersController(IDatabaseService databaseService, AppDbContext appDbContext)
        {
            _databaseService = databaseService;
            _appDbContext = appDbContext;
        }

        [HttpGet]
        public async Task<ActionResult<IEnumerable<Order>>> GetAll()
        {
            try
            {
                var email = User.FindFirst(ClaimTypes.Email)?.Value ?? string.Empty;
                var userLogin = User.FindFirst(ClaimTypes.Name)?.Value ?? string.Empty;

                if (string.IsNullOrEmpty(email) || string.IsNullOrEmpty(userLogin))
                    return Unauthorized("Thông tin xác thực không hợp lệ");

                var dbContext = await _databaseService.GetDynamicDbContextAsync(email, userLogin, "");
                return await dbContext.Orders
                    .Include(o => o.Sender)
                    .Include(o => o.Receiver)
                    .Include(o => o.OrderItems)
                    .Include(o => o.Payment)
                    .Include(o => o.Route)
                    .Include(o => o.Trip)
                    .AsNoTracking()
                    .ToListAsync();
            }
            catch (Exception ex)
            {
                return BadRequest($"Không thể kết nối database: {ex.Message}");
            }
        }

        [HttpGet("{id}")]
        public async Task<ActionResult<Order>> GetById(Guid id)
        {
            try
            {
                var email = User.FindFirst(ClaimTypes.Email)?.Value;
                var userLogin = User.FindFirst(ClaimTypes.Name)?.Value;

                if (string.IsNullOrEmpty(email) || string.IsNullOrEmpty(userLogin))
                    return Unauthorized("Thông tin xác thực không hợp lệ");

                var dbContext = await _databaseService.GetDynamicDbContextAsync(email, userLogin, "");
                var entity = await dbContext.Orders
                    .Include(o => o.Sender)
                    .Include(o => o.Receiver)
                    .Include(o => o.OrderItems)
                    .Include(o => o.Payment)
                    .Include(o => o.Route)
                    .Include(o => o.Trip)
                    .FirstOrDefaultAsync(o => o.OrderID == id);
                    
                if (entity == null) return NotFound();
                return entity;
            }
            catch (Exception ex)
            {
                return BadRequest($"Không thể kết nối database: {ex.Message}");
            }
        }

        [HttpPost]
        public async Task<ActionResult<Order>> Create([FromBody] CreateOrderRequest request)
        {
            try
            {
                var email = User.FindFirst(ClaimTypes.Email)?.Value;
                var userLogin = User.FindFirst(ClaimTypes.Name)?.Value;

                if (string.IsNullOrEmpty(email) || string.IsNullOrEmpty(userLogin))
                    return Unauthorized("Thông tin xác thực không hợp lệ");

                var dbContext = await _databaseService.GetDynamicDbContextAsync(email, userLogin, "");

                var strategy = dbContext.Database.CreateExecutionStrategy();
                return await strategy.ExecuteAsync(async () =>
                {
                    await using var transaction = await dbContext.Database.BeginTransactionAsync();
                    try
                    {
                        // Create or get Sender
                        Sender? sender = null;
                        if (!string.IsNullOrEmpty(request.Sender?.Phone))
                        {
                            sender = await dbContext.Senders.FirstOrDefaultAsync(s => s.Phone == request.Sender.Phone);
                            if (sender == null)
                            {
                                sender = request.Sender;
                                if (sender.SenderID == Guid.Empty)
                                    sender.SenderID = Guid.NewGuid();
                                dbContext.Senders.Add(sender);
                                await dbContext.SaveChangesAsync();
                            }
                            else
                            {
                                // Update existing sender
                                sender.Name = request.Sender.Name ?? sender.Name;
                                sender.Address = request.Sender.Address ?? sender.Address;
                                sender.BranchID = request.Sender.BranchID ?? sender.BranchID;
                                sender.District = request.Sender.District ?? sender.District;
                                sender.PickupRequired = request.Sender.PickupRequired;
                                sender.PickupStaffID = request.Sender.PickupStaffID ?? sender.PickupStaffID;
                                dbContext.Entry(sender).State = EntityState.Modified;
                            }
                        }

                        // Create or get Receiver
                        Receiver? receiver = null;
                        if (!string.IsNullOrEmpty(request.Receiver?.Phone))
                        {
                            receiver = await dbContext.Receivers.FirstOrDefaultAsync(r => r.Phone == request.Receiver.Phone);
                            if (receiver == null)
                            {
                                receiver = request.Receiver;
                                if (receiver.ReceiverID == Guid.Empty)
                                    receiver.ReceiverID = Guid.NewGuid();
                                dbContext.Receivers.Add(receiver);
                                await dbContext.SaveChangesAsync();
                            }
                            else
                            {
                                // Update existing receiver
                                receiver.Name = request.Receiver.Name ?? receiver.Name;
                                receiver.Address = request.Receiver.Address ?? receiver.Address;
                                receiver.BranchID = request.Receiver.BranchID ?? receiver.BranchID;
                                receiver.District = request.Receiver.District ?? receiver.District;
                                receiver.DeliveryRequired = request.Receiver.DeliveryRequired;
                                receiver.DeliveryStaffID = request.Receiver.DeliveryStaffID ?? receiver.DeliveryStaffID;
                                dbContext.Entry(receiver).State = EntityState.Modified;
                            }
                        }

                        // Create Order
                        var order = request.Order;
                        if (order.OrderID == Guid.Empty)
                            order.OrderID = Guid.NewGuid();
                        
                        order.SenderID = sender?.SenderID;
                        order.ReceiverID = receiver?.ReceiverID;
                        order.CreatedBy = email;
                        
                        dbContext.Orders.Add(order);
                        await dbContext.SaveChangesAsync();

                        // Create OrderItems (clear Order nav to avoid duplicate tracking)
                        if (request.OrderItems != null && request.OrderItems.Any())
                        {
                            foreach (var item in request.OrderItems)
                            {
                                if (item.ItemID == Guid.Empty)
                                    item.ItemID = Guid.NewGuid();
                                item.OrderID = order.OrderID;
                                item.Order = null!; // Avoid duplicate Order tracking
                                dbContext.OrderItems.Add(item);
                            }
                            await dbContext.SaveChangesAsync();
                        }

                        // Create Payment (clear Order nav to avoid duplicate tracking)
                        if (request.Payment != null)
                        {
                            if (request.Payment.PaymentID == Guid.Empty)
                                request.Payment.PaymentID = Guid.NewGuid();
                            request.Payment.OrderID = order.OrderID;
                            request.Payment.Order = null!; // Avoid duplicate Order tracking
                            dbContext.Payments.Add(request.Payment);
                            await dbContext.SaveChangesAsync();
                        }

                        await transaction.CommitAsync();

                        // Reload order with all relations
                        var createdOrder = await dbContext.Orders
                            .Include(o => o.Sender)
                            .Include(o => o.Receiver)
                            .Include(o => o.OrderItems)
                            .Include(o => o.Payment)
                            .Include(o => o.Route)
                            .Include(o => o.Trip)
                            .FirstOrDefaultAsync(o => o.OrderID == order.OrderID);

                        return CreatedAtAction(nameof(GetById), new { id = order.OrderID }, createdOrder);
                    }
                    catch
                    {
                        await transaction.RollbackAsync();
                        throw;
                    }
                });
            }
            catch (Exception ex)
            {
                return BadRequest($"Không thể tạo order: {ex.Message}");
            }
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> Update(Guid id, [FromBody] CreateOrderRequest request)
        {
            if (id != request.Order.OrderID)
                return BadRequest();

            try
            {
                var email = User.FindFirst(ClaimTypes.Email)?.Value;
                var userLogin = User.FindFirst(ClaimTypes.Name)?.Value;

                if (string.IsNullOrEmpty(email) || string.IsNullOrEmpty(userLogin))
                    return Unauthorized("Thông tin xác thực không hợp lệ");

                var dbContext = await _databaseService.GetDynamicDbContextAsync(email, userLogin, "");

                var strategy = dbContext.Database.CreateExecutionStrategy();
                return await strategy.ExecuteAsync(async () =>
                {
                    await using var transaction = await dbContext.Database.BeginTransactionAsync();
                    try
                    {
                        // Update Sender if provided
                        if (request.Sender != null && !string.IsNullOrEmpty(request.Sender.Phone))
                        {
                            var sender = await dbContext.Senders.FirstOrDefaultAsync(s => s.SenderID == request.Sender.SenderID);
                            if (sender != null)
                            {
                                sender.Name = request.Sender.Name;
                                sender.Address = request.Sender.Address;
                                sender.BranchID = request.Sender.BranchID;
                                sender.District = request.Sender.District;
                                sender.PickupRequired = request.Sender.PickupRequired;
                                sender.PickupStaffID = request.Sender.PickupStaffID;
                                dbContext.Entry(sender).State = EntityState.Modified;
                            }
                        }

                        // Update Receiver if provided
                        if (request.Receiver != null && !string.IsNullOrEmpty(request.Receiver.Phone))
                        {
                            var receiver = await dbContext.Receivers.FirstOrDefaultAsync(r => r.ReceiverID == request.Receiver.ReceiverID);
                            if (receiver != null)
                            {
                                receiver.Name = request.Receiver.Name;
                                receiver.Address = request.Receiver.Address;
                                receiver.BranchID = request.Receiver.BranchID;
                                receiver.District = request.Receiver.District;
                                receiver.DeliveryRequired = request.Receiver.DeliveryRequired;
                                receiver.DeliveryStaffID = request.Receiver.DeliveryStaffID;
                                dbContext.Entry(receiver).State = EntityState.Modified;
                            }
                        }

                        // Update Order
                        dbContext.Entry(request.Order).State = EntityState.Modified;

                        // Update OrderItems (delete old, add new)
                        var existingItems = await dbContext.OrderItems.Where(oi => oi.OrderID == id).ToListAsync();
                        dbContext.OrderItems.RemoveRange(existingItems);
                        
                        if (request.OrderItems != null && request.OrderItems.Any())
                        {
                            foreach (var item in request.OrderItems)
                            {
                                if (item.ItemID == Guid.Empty)
                                    item.ItemID = Guid.NewGuid();
                                item.OrderID = id;
                                item.Order = null!; // Avoid duplicate Order tracking
                                dbContext.OrderItems.Add(item);
                            }
                        }

                        // Update Payment
                        var existingPayment = await dbContext.Payments.FirstOrDefaultAsync(p => p.OrderID == id);
                        if (request.Payment != null)
                        {
                            if (existingPayment != null)
                            {
                                existingPayment.ShippingFee = request.Payment.ShippingFee;
                                existingPayment.CODAmount = request.Payment.CODAmount;
                                existingPayment.CODFee = request.Payment.CODFee;
                                existingPayment.TotalPayment = request.Payment.TotalPayment;
                                existingPayment.PaymentMethod = request.Payment.PaymentMethod;
                                dbContext.Entry(existingPayment).State = EntityState.Modified;
                            }
                            else
                            {
                                if (request.Payment.PaymentID == Guid.Empty)
                                    request.Payment.PaymentID = Guid.NewGuid();
                                request.Payment.OrderID = id;
                                request.Payment.Order = null!; // Avoid duplicate Order tracking
                                dbContext.Payments.Add(request.Payment);
                            }
                        }

                        await dbContext.SaveChangesAsync();
                        await transaction.CommitAsync();
                        return NoContent();
                    }
                    catch
                    {
                        await transaction.RollbackAsync();
                        throw;
                    }
                });
            }
            catch (DbUpdateConcurrencyException)
            {
                return NotFound();
            }
            catch (Exception ex)
            {
                return BadRequest($"Không thể cập nhật order: {ex.Message}");
            }
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> Delete(string id)
        {
            try
            {
                var email = User.FindFirst(ClaimTypes.Email)?.Value;
                var userLogin = User.FindFirst(ClaimTypes.Name)?.Value;

                if (string.IsNullOrEmpty(email) || string.IsNullOrEmpty(userLogin))
                    return Unauthorized("Thông tin xác thực không hợp lệ");

                var dbContext = await _databaseService.GetDynamicDbContextAsync(email, userLogin, "");
                var entity = await dbContext.Orders.FindAsync(id);
                if (entity == null) return NotFound();

                dbContext.Orders.Remove(entity);
                await dbContext.SaveChangesAsync();
                return NoContent();
            }
            catch (Exception ex)
            {
                return BadRequest($"Không thể xóa order: {ex.Message}");
            }
        }
    }

    public class CreateOrderRequest
    {
        public Order Order { get; set; } = null!;
        public Sender? Sender { get; set; }
        public Receiver? Receiver { get; set; }
        public List<OrderItem>? OrderItems { get; set; }
        public Payment? Payment { get; set; }
    }
}
