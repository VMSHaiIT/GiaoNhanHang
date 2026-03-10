using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace GiaoNhanHangApi.Models
{
    [Table("Vehicles")]
    public class Vehicle
    {
        [Key]
        public Guid VehicleID { get; set; }
        
        public string VehicleName { get; set; } = string.Empty;
        
        public virtual ICollection<Trip> Trips { get; set; } = new List<Trip>();
    }
}
