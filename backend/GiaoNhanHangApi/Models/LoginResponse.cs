namespace GiaoNhanHangApi.Models
{
    public class LoginResponse
    {
        public bool Success { get; set; }
        public string Message { get; set; } = string.Empty;
        public string? Token { get; set; }
        public string? RefreshToken { get; set; }
        public string? UserRole { get; set; }
        public string? DatabaseName { get; set; }
    }
}
