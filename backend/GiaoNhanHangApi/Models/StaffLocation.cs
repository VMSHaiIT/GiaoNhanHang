using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace GiaoNhanHangApi.Models
{
    [Table("StaffLocations")]
    public class StaffLocation
    {
        [Key]
        public Guid LocationID { get; set; } = Guid.NewGuid();

        /// <summary>ID của staff đang phát vị trí</summary>
        public Guid StaffID { get; set; }

        /// <summary>ID chuyến đi staff đang thực hiện</summary>
        public Guid TripID { get; set; }

        public double Latitude { get; set; }

        public double Longitude { get; set; }

        /// <summary>Tốc độ (km/h), nullable</summary>
        public double? SpeedKmh { get; set; }

        /// <summary>Hướng đi (độ 0-360), nullable</summary>
        public double? Heading { get; set; }

        public DateTime Timestamp { get; set; } = DateTime.UtcNow;

        /// <summary>true = đang chia sẻ vị trí, false = đã dừng</summary>
        public bool IsActive { get; set; } = true;

        // Navigation properties
        [ForeignKey("StaffID")]
        public virtual Staff? Staff { get; set; }

        [ForeignKey("TripID")]
        public virtual Trip? Trip { get; set; }
    }
}
