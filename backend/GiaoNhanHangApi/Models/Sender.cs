using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace GiaoNhanHangApi.Models
{
    [Table("Senders")]
    public class Sender
    {
        [Key]
        public Guid SenderID { get; set; }
        
        public string Phone { get; set; } = string.Empty;
        
        public string Name { get; set; } = string.Empty;
        
        public string? Address { get; set; }
        
        public Guid? BranchID { get; set; }
        
        public string? District { get; set; }
        
        public bool PickupRequired { get; set; }
        
        public Guid? PickupStaffID { get; set; }
        
        // Navigation properties
        [ForeignKey("BranchID")]
        public virtual Branch? Branch { get; set; }
        
        [ForeignKey("PickupStaffID")]
        public virtual Staff? PickupStaff { get; set; }
        
        public virtual ICollection<Order> Orders { get; set; } = new List<Order>();
    }
}
