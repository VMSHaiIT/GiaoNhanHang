namespace GiaoNhanHangApi.Models
{
    public class CheckEmailResponse
    {
        public bool Exists { get; set; }
        public string Message { get; set; } = string.Empty;
    }
}
