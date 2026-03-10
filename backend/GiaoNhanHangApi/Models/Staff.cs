using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace GiaoNhanHangApi.Models
{
    [Table("Staff")]
    public class Staff
    {
        [Key]
        public Guid StaffID { get; set; }
        
        public string Name { get; set; } = string.Empty;
        
        public string Phone { get; set; } = string.Empty;
        
        // Navigation properties
        public virtual ICollection<Sender> PickupSenders { get; set; } = new List<Sender>();
        
        public virtual ICollection<Receiver> DeliveryReceivers { get; set; } = new List<Receiver>();
        
        public virtual ICollection<Trip> DriverTrips { get; set; } = new List<Trip>();
    }
}
