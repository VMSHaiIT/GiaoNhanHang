using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace GiaoNhanHangApi.Models
{
    [Table("Branches")]
    public class Branch
    {
        [Key]
        public Guid BranchID { get; set; }
        
        public string BranchName { get; set; } = string.Empty;
        
        public virtual ICollection<Sender> Senders { get; set; } = new List<Sender>();
        
        public virtual ICollection<Receiver> Receivers { get; set; } = new List<Receiver>();
    }
}
