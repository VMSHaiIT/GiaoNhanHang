using System.Security.Cryptography;
using System.Text;

namespace GiaoNhanHangApi.Services
{
    public interface IPasswordService
    {
        string HashPassword(string password);
        bool VerifyPassword(string password, string hashedPassword);
        string EncryptPasswordLogin(string passwordLogin);
        string DecryptPasswordLogin(string encryptedPasswordLogin);
    }

    public class PasswordService : IPasswordService
    {
        private readonly string _encryptionKey;
        private readonly string _iv;

        public PasswordService(IConfiguration configuration)
        {
            _encryptionKey = configuration["Encryption:Key"] ?? throw new InvalidOperationException("Encryption:Key not configured");
            _iv = configuration["Encryption:IV"] ?? throw new InvalidOperationException("Encryption:IV not configured");
            
            if (_encryptionKey.Length != 32)
            {
                throw new InvalidOperationException($"Encryption key must be exactly 32 characters long, got {_encryptionKey.Length}");
            }
            
            if (_iv.Length != 16)
            {
                throw new InvalidOperationException($"IV must be exactly 16 characters long, got {_iv.Length}");
            }
        }

        public string HashPassword(string password)
        {
            byte[] salt = new byte[16];
            using (var rng = RandomNumberGenerator.Create())
            {
                rng.GetBytes(salt);
            }

            var passwordWithSalt = Encoding.UTF8.GetBytes(password);
            var combined = new byte[salt.Length + passwordWithSalt.Length];
            Array.Copy(salt, 0, combined, 0, salt.Length);
            Array.Copy(passwordWithSalt, 0, combined, salt.Length, passwordWithSalt.Length);

            using (var sha256 = SHA256.Create())
            {
                var hash = sha256.ComputeHash(combined);
                
                var result = new byte[salt.Length + hash.Length];
                Array.Copy(salt, 0, result, 0, salt.Length);
                Array.Copy(hash, 0, result, salt.Length, hash.Length);
                
                return Convert.ToBase64String(result);
            }
        }

        public bool VerifyPassword(string password, string hashedPassword)
        {
            try
            {
                var hashedBytes = Convert.FromBase64String(hashedPassword);
                
                var salt = new byte[16];
                Array.Copy(hashedBytes, 0, salt, 0, 16);
                
                var hash = new byte[hashedBytes.Length - 16];
                Array.Copy(hashedBytes, 16, hash, 0, hash.Length);
                
                var passwordWithSalt = Encoding.UTF8.GetBytes(password);
                var combined = new byte[salt.Length + passwordWithSalt.Length];
                Array.Copy(salt, 0, combined, 0, salt.Length);
                Array.Copy(passwordWithSalt, 0, combined, salt.Length, passwordWithSalt.Length);
                
                using (var sha256 = SHA256.Create())
                {
                    var computedHash = sha256.ComputeHash(combined);
                    return hash.SequenceEqual(computedHash);
                }
            }
            catch
            {
                return false;
            }
        }

        public string EncryptPasswordLogin(string passwordLogin)
        {
            try
            {
                using (var aes = Aes.Create())
                {
                    var keyBytes = Encoding.UTF8.GetBytes(_encryptionKey);
                    var ivBytes = Encoding.UTF8.GetBytes(_iv);
                    
                    aes.Key = keyBytes;
                    aes.IV = ivBytes;

                    using (var encryptor = aes.CreateEncryptor())
                    using (var msEncrypt = new MemoryStream())
                    {
                        using (var csEncrypt = new CryptoStream(msEncrypt, encryptor, CryptoStreamMode.Write))
                        using (var swEncrypt = new StreamWriter(csEncrypt))
                        {
                            swEncrypt.Write(passwordLogin);
                        }

                        return Convert.ToBase64String(msEncrypt.ToArray());
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error encrypting password: {ex.Message}");
                Console.WriteLine($"Stack trace: {ex.StackTrace}");
                throw new InvalidOperationException($"Failed to encrypt password: {ex.Message}", ex);
            }
        }

        public string DecryptPasswordLogin(string encryptedPasswordLogin)
        {
            try
            {
                using (var aes = Aes.Create())
                {
                    var keyBytes = Encoding.UTF8.GetBytes(_encryptionKey);
                    var ivBytes = Encoding.UTF8.GetBytes(_iv);
                    
                    aes.Key = keyBytes;
                    aes.IV = ivBytes;

                    using (var decryptor = aes.CreateDecryptor())
                    using (var msDecrypt = new MemoryStream(Convert.FromBase64String(encryptedPasswordLogin)))
                    using (var csDecrypt = new CryptoStream(msDecrypt, decryptor, CryptoStreamMode.Read))
                    using (var srDecrypt = new StreamReader(csDecrypt))
                    {
                        return srDecrypt.ReadToEnd();
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error decrypting password: {ex.Message}");
                Console.WriteLine($"Stack trace: {ex.StackTrace}");
                throw new InvalidOperationException($"Failed to decrypt password: {ex.Message}", ex);
            }
        }
    }
}
