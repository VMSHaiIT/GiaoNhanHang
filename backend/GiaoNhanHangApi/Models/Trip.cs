using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace GiaoNhanHangApi.Models
{
    [Table("Trips")]
    public class Trip
    {
        [Key]
        public Guid TripID { get; set; }
        
        public Guid RouteID { get; set; }
        
        public Guid? VehicleID { get; set; }
        
        public Guid? DriverID { get; set; }
        
        public DateTime? DepartureTime { get; set; }
        
        public DateTime? ArrivalTime { get; set; }
        
        public string Status { get; set; } = string.Empty;
        
        // Navigation properties (nullable for API input; EF uses RouteID for FK)
        [ForeignKey("RouteID")]
        public virtual Route? Route { get; set; }
        
        [ForeignKey("VehicleID")]
        public virtual Vehicle? Vehicle { get; set; }
        
        [ForeignKey("DriverID")]
        public virtual Staff? Driver { get; set; }
    }
}
