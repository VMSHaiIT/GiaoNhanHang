using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace GiaoNhanHangApi.Models
{
    [Table("Orders")]
    public class Order
    {
        [Key]
        public Guid OrderID { get; set; }
        
        public DateTime OrderDate { get; set; }
        
        public DateTime ExpectedDeliveryDate { get; set; }
        
        public string OrderType { get; set; } = string.Empty;
        
        [Column(TypeName = "decimal(18,2)")]
        public decimal TotalValue { get; set; }
        
        public string? Note { get; set; }
        
        [Column(TypeName = "decimal(18,2)")]
        public decimal TotalWeight { get; set; }
        
        [Column(TypeName = "decimal(18,2)")]
        public decimal TotalAmount { get; set; }
        
        public string Status { get; set; } = string.Empty;
        
        public DateTime CreatedDate { get; set; } = DateTime.UtcNow;
        
        public string CreatedBy { get; set; } = string.Empty;
        
        // Foreign keys
        public Guid? SenderID { get; set; }
        public Guid? ReceiverID { get; set; }
        public Guid? RouteID { get; set; }
        public Guid? TripID { get; set; }
        
        // Navigation properties
        [ForeignKey("SenderID")]
        public virtual Sender? Sender { get; set; }
        
        [ForeignKey("ReceiverID")]
        public virtual Receiver? Receiver { get; set; }
        
        [ForeignKey("RouteID")]
        public virtual Route? Route { get; set; }
        
        [ForeignKey("TripID")]
        public virtual Trip? Trip { get; set; }
        
        public virtual ICollection<OrderItem> OrderItems { get; set; } = new List<OrderItem>();
        
        public virtual Payment? Payment { get; set; }
    }
}
