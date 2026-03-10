using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace GiaoNhanHangApi.Models
{
    [Table("Receivers")]
    public class Receiver
    {
        [Key]
        public Guid ReceiverID { get; set; }
        
        public string Phone { get; set; } = string.Empty;
        
        public string Name { get; set; } = string.Empty;
        
        public string? Address { get; set; }
        
        public Guid? BranchID { get; set; }
        
        public string? District { get; set; }
        
        public bool DeliveryRequired { get; set; }
        
        public Guid? DeliveryStaffID { get; set; }
        
        // Navigation properties
        [ForeignKey("BranchID")]
        public virtual Branch? Branch { get; set; }
        
        [ForeignKey("DeliveryStaffID")]
        public virtual Staff? DeliveryStaff { get; set; }
        
        public virtual ICollection<Order> Orders { get; set; } = new List<Order>();
    }
}
