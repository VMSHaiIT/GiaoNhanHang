using Microsoft.Data.SqlClient;
using GiaoNhanHangApi.Data;
using Microsoft.EntityFrameworkCore;

namespace GiaoNhanHangApi.Services
{
    public interface IDatabaseService
    {
        Task<DynamicDbContext> GetDynamicDbContextAsync(string email, string userLogin, string passwordLogin);
        Task<bool> TestConnectionAsync(string databaseName, string userLogin, string passwordLogin);
    }

    public class DatabaseService : IDatabaseService
    {
        private readonly IConfiguration _configuration;
        private readonly AppDbContext _adminContext;
        private readonly IPasswordService _passwordService;

        public DatabaseService(IConfiguration configuration, AppDbContext adminContext, IPasswordService passwordService)
        {
            _configuration = configuration;
            _adminContext = adminContext;
            _passwordService = passwordService;
        }

        public async Task<DynamicDbContext> GetDynamicDbContextAsync(string email, string userLogin, string passwordLogin)
        {
            if (string.IsNullOrEmpty(passwordLogin))
            {
                try
                {
                    var user = await _adminContext.Users.FirstOrDefaultAsync(u => u.Email == email);
                    if (user != null)
                    {
                        passwordLogin = _passwordService.DecryptPasswordLogin(user.PasswordLogin);
                    }
                }
                catch (Exception ex)
                {
                    throw new Exception($"Không thể lấy thông tin đăng nhập database: {ex.Message}");
                }
            }

            if (string.IsNullOrEmpty(passwordLogin))
            {
                throw new Exception("Không thể xác định mật khẩu database. Vui lòng đăng nhập lại.");
            }

            var databaseName = email;
            var connectionString = $"Server=115.78.95.245;Database={databaseName};User Id={userLogin};Password={passwordLogin};TrustServerCertificate=True;";
            
            Console.WriteLine($"DatabaseService.GetDynamicDbContextAsync: Database name = {databaseName}, UserLogin = {userLogin}");
            
            return new DynamicDbContext(connectionString);
        }

        public async Task<bool> TestConnectionAsync(string databaseName, string userLogin, string passwordLogin)
        {
            try
            {
                var connectionString = $"Server=115.78.95.245;Database={databaseName};User Id={userLogin};Password={passwordLogin};TrustServerCertificate=True;";
                
                using (var connection = new SqlConnection(connectionString))
                {
                    await connection.OpenAsync();
                    return true;
                }
            }
            catch
            {
                return false;
            }
        }
    }
}
