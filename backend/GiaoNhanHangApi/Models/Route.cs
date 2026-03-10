using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace GiaoNhanHangApi.Models
{
    [Table("Routes")]
    public class Route
    {
        [Key]
        public Guid RouteID { get; set; }
        
        public string RouteName { get; set; } = string.Empty;
        
        public string Origin { get; set; } = string.Empty;
        
        public string Destination { get; set; } = string.Empty;
        
        public string TransportType { get; set; } = string.Empty;
        
        public virtual ICollection<Trip> Trips { get; set; } = new List<Trip>();
    }
}
