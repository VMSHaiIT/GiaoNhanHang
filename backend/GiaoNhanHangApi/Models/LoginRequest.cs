namespace GiaoNhanHangApi.Models
{
    public class LoginRequest
    {
        public string Email { get; set; } = string.Empty;
        public string UserLogin { get; set; } = string.Empty;
        public string PasswordLogin { get; set; } = string.Empty;
    }
}
