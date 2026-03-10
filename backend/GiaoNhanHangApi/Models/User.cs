using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace GiaoNhanHangApi.Models
{
    [Table("Users")]
    public class User
    {
        [Key]
        public string Email { get; set; } = string.Empty;
        public string UserLogin { get; set; } = string.Empty;
        public string PasswordLogin { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}
