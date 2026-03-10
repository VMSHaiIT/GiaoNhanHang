using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace GiaoNhanHangApi.Models
{
    [Table("OrderItems")]
    public class OrderItem
    {
        [Key]
        public Guid ItemID { get; set; }
        
        public Guid OrderID { get; set; }
        
        public string ItemName { get; set; } = string.Empty;
        
        public string Unit { get; set; } = string.Empty;
        
        [Column(TypeName = "decimal(18,2)")]
        public decimal Weight { get; set; }
        
        public int Quantity { get; set; }
        
        [Column(TypeName = "decimal(18,2)")]
        public decimal Price { get; set; }
        
        [Column(TypeName = "decimal(18,2)")]
        public decimal Amount { get; set; }
        
        // Navigation property
        [ForeignKey("OrderID")]
        public virtual Order Order { get; set; } = null!;
    }
}
