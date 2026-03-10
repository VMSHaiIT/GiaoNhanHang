using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace GiaoNhanHangApi.Models
{
    [Table("Payments")]
    public class Payment
    {
        [Key]
        public Guid PaymentID { get; set; }
        
        public Guid OrderID { get; set; }
        
        [Column(TypeName = "decimal(18,2)")]
        public decimal ShippingFee { get; set; }
        
        [Column(TypeName = "decimal(18,2)")]
        public decimal CODAmount { get; set; }
        
        [Column(TypeName = "decimal(18,2)")]
        public decimal CODFee { get; set; }
        
        [Column(TypeName = "decimal(18,2)")]
        public decimal TotalPayment { get; set; }
        
        public string PaymentMethod { get; set; } = string.Empty;
        
        // Navigation property
        [ForeignKey("OrderID")]
        public virtual Order Order { get; set; } = null!;
    }
}
