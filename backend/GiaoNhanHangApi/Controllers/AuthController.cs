using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Data.SqlClient;
using GiaoNhanHangApi.Data;
using GiaoNhanHangApi.Models;
using GiaoNhanHangApi.Services;
using System.Security.Claims;

namespace GiaoNhanHangApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AuthController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IConfiguration _configuration;
        private readonly IJwtService _jwtService;
        private readonly IPasswordService _passwordService;

        public AuthController(AppDbContext context, IConfiguration configuration, IJwtService jwtService, IPasswordService passwordService)
        {
            _context = context;
            _configuration = configuration;
            _jwtService = jwtService;
            _passwordService = passwordService;
        }

        [HttpPost("check-email")]
        public async Task<ActionResult<CheckEmailResponse>> CheckEmail([FromBody] CheckEmailRequest? request)
        {
            if (request == null || string.IsNullOrWhiteSpace(request.Email))
            {
                return BadRequest(new CheckEmailResponse
                {
                    Exists = false,
                    Message = "Email không được để trống."
                });
            }

            try
            {
                var email = request.Email.Trim().ToLowerInvariant();
                var existingUser = await _context.Users
                    .AsNoTracking()
                    .FirstOrDefaultAsync(u => u.Email != null && u.Email.ToLower() == email);

                if (existingUser != null)
                {
                    return Ok(new CheckEmailResponse
                    {
                        Exists = true,
                        Message = "Email đã tồn tại trong hệ thống! Vui lòng nhập mật khẩu để đăng nhập."
                    });
                }

                return Ok(new CheckEmailResponse
                {
                    Exists = false,
                    Message = "Email chưa tồn tại. Vui lòng tạo tài khoản mới!"
                });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[CheckEmail] Error: {ex.Message}");
                Console.WriteLine($"[CheckEmail] Stack: {ex.StackTrace}");
                return StatusCode(500, new CheckEmailResponse
                {
                    Exists = false,
                    Message = "Không thể kiểm tra email. Vui lòng thử lại sau."
                });
            }
        }

        [HttpPost("login")]
        public async Task<ActionResult<LoginResponse>> Login([FromBody] LoginRequest request)
        {
            try
            {
                Console.WriteLine($"Login attempt for email: {request.Email}");

                var existingUser = await _context.Users.FirstOrDefaultAsync(u => u.Email.ToLower() == request.Email.ToLower());

                if (existingUser == null)
                {
                    Console.WriteLine("User not found, creating new user...");
                    var newUser = new User
                    {
                        Email = request.Email.ToLower(),
                        UserLogin = request.UserLogin.ToLower(),
                        PasswordLogin = _passwordService.EncryptPasswordLogin(request.PasswordLogin)
                    };

                    _context.Users.Add(newUser);
                    await _context.SaveChangesAsync();
                    Console.WriteLine("New user created successfully");

                    var databaseName = request.Email.ToLower();
                    Console.WriteLine($"Creating dynamic database: {databaseName}");
                    var success = await CreateDynamicDatabase(databaseName, request.UserLogin.ToLower(), request.PasswordLogin);

                    if (!success)
                    {
                        Console.WriteLine("Failed to create database, rolling back user creation...");
                        _context.Users.Remove(newUser);
                        await _context.SaveChangesAsync();

                        return BadRequest(new LoginResponse
                        {
                            Success = false,
                            Message = "Tạo tài khoản thành công nhưng không thể tạo database. Vui lòng kiểm tra quyền truy cập hoặc liên hệ admin."
                        });
                    }

                    Console.WriteLine("Database created successfully, generating token...");
                    var accessToken = _jwtService.GenerateToken(request.Email.ToLower(), request.UserLogin.ToLower(), "shop_owner");
                    var refreshToken = _jwtService.GenerateRefreshToken(request.Email.ToLower(), request.UserLogin.ToLower(), "shop_owner");
                    return Ok(new LoginResponse
                    {
                        Success = true,
                        Message = "Tạo tài khoản và database thành công",
                        DatabaseName = databaseName,
                        Token = accessToken,
                        RefreshToken = refreshToken,
                        UserRole = "shop_owner"
                    });
                }
                else
                {
                    Console.WriteLine("User exists, verifying credentials...");
                    var userLoginMatch = existingUser.UserLogin.ToLower() == request.UserLogin.ToLower();
                    var passwordLoginMatch = request.PasswordLogin == _passwordService.DecryptPasswordLogin(existingUser.PasswordLogin);

                    Console.WriteLine($"User login match: {userLoginMatch}, Password login match: {passwordLoginMatch}");

                    if (!userLoginMatch || !passwordLoginMatch)
                    {
                        string errorMessage = "";
                        if (!userLoginMatch && !passwordLoginMatch)
                        {
                            errorMessage = "Tên đăng nhập và mật khẩu không chính xác.";
                        }
                        else if (!userLoginMatch)
                        {
                            errorMessage = "Tên đăng nhập không chính xác.";
                        }
                        else
                        {
                            errorMessage = "Mật khẩu không chính xác.";
                        }

                        Console.WriteLine($"Database credentials mismatch: {errorMessage}");
                        return BadRequest(new LoginResponse
                        {
                            Success = false,
                            Message = errorMessage
                        });
                    }

                    Console.WriteLine("All credentials verified, generating token...");
                    var accessToken = _jwtService.GenerateToken(request.Email.ToLower(), request.UserLogin.ToLower(), "shop_owner");
                    var refreshToken = _jwtService.GenerateRefreshToken(request.Email.ToLower(), request.UserLogin.ToLower(), "shop_owner");
                    return Ok(new LoginResponse
                    {
                        Success = true,
                        Message = "Đăng nhập thành công",
                        DatabaseName = request.Email.ToLower(),
                        Token = accessToken,
                        RefreshToken = refreshToken,
                        UserRole = "shop_owner"
                    });
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Login error: {ex.Message}");
                Console.WriteLine($"Stack trace: {ex.StackTrace}");

                return StatusCode(500, new LoginResponse
                {
                    Success = false,
                    Message = "Đã xảy ra lỗi hệ thống. Vui lòng thử lại sau hoặc liên hệ admin."
                });
            }
        }

        private async Task<bool> CreateDynamicDatabase(string databaseName, string dbUser, string dbPassword)
        {
            try
            {
                var masterConnectionString = _configuration.GetConnectionString("Master") ??
                    "Server=115.78.95.245;Database=master;User Id=sa;Password=qwerQWER1234!@#$;TrustServerCertificate=True;";

                Console.WriteLine($"Attempting to create database: {databaseName}");
                Console.WriteLine($"Using master connection: {masterConnectionString}");

                using (var connection = new SqlConnection(masterConnectionString))
                {
                    await connection.OpenAsync();
                    Console.WriteLine("Connected to master database successfully");

                    var checkDbCommand = new SqlCommand($"SELECT COUNT(*) FROM sys.databases WHERE name = '{databaseName}'", connection);
                    var dbExists = (int)(await checkDbCommand.ExecuteScalarAsync() ?? 0);

                    if (dbExists == 0)
                    {
                        Console.WriteLine($"Creating new database: {databaseName}");
                        var createDbCommand = new SqlCommand($"CREATE DATABASE [{databaseName}]", connection);
                        await createDbCommand.ExecuteNonQueryAsync();
                        Console.WriteLine($"Database {databaseName} created successfully");
                    }
                    else
                    {
                        Console.WriteLine($"Database {databaseName} already exists");
                    }

                    try
                    {
                        var isPasswordStrong = dbPassword.Length >= 8 &&
                                               dbPassword.Any(char.IsUpper) &&
                                               dbPassword.Any(char.IsLower) &&
                                               dbPassword.Any(char.IsDigit) &&
                                               dbPassword.Any(c => "!@#$%^&*()_+-=[]{}|;:,.<>?".Contains(c));

                        if (!isPasswordStrong)
                        {
                            Console.WriteLine("Password is not strong enough");
                            return false;
                        }

                        Console.WriteLine($"Creating login for user: {dbUser}");
                        var createLoginCommand = new SqlCommand($@"
                            IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = '{dbUser}')
                            BEGIN
                                CREATE LOGIN [{dbUser}] WITH PASSWORD = '{dbPassword}', CHECK_POLICY = OFF, CHECK_EXPIRATION = OFF;
                            END", connection);
                        await createLoginCommand.ExecuteNonQueryAsync();
                        Console.WriteLine($"Login {dbUser} created successfully");

                        var createUserCommand = new SqlCommand($@"
                            USE [{databaseName}];
                            IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = '{dbUser}')
                            BEGIN
                                CREATE USER [{dbUser}] FOR LOGIN [{dbUser}];
                            END", connection);
                        await createUserCommand.ExecuteNonQueryAsync();
                        Console.WriteLine($"User {dbUser} created in database {databaseName}");

                        var grantDbOwnerCommand = new SqlCommand($@"
                            USE [{databaseName}];
                            ALTER ROLE db_owner ADD MEMBER [{dbUser}];", connection);
                        await grantDbOwnerCommand.ExecuteNonQueryAsync();
                        Console.WriteLine($"db_owner role granted to {dbUser}");
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine($"Error creating login/user: {ex.Message}");
                        return false;
                    }
                }

                Console.WriteLine("Creating tables in new database...");
                var tablesCreated = await CreateTablesInDynamicDatabase(databaseName, dbUser, dbPassword);

                if (tablesCreated)
                {
                    Console.WriteLine("All tables created successfully");
                    return true;
                }
                else
                {
                    Console.WriteLine("Failed to create some tables");
                    return false;
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error in CreateDynamicDatabase: {ex.Message}");
                Console.WriteLine($"Stack trace: {ex.StackTrace}");
                return false;
            }
        }

        private async Task<bool> CreateTablesInDynamicDatabase(string databaseName, string dbUser, string dbPassword)
        {
            try
            {
                Console.WriteLine($"Connecting to new database: {databaseName}");
                var newDbConnectionString = $"Server=115.78.95.245;Database={databaseName};User Id={dbUser};Password={dbPassword};TrustServerCertificate=True;";

                try
                {
                    using (var testConnection = new SqlConnection(newDbConnectionString))
                    {
                        await testConnection.OpenAsync();
                        Console.WriteLine("Test connection successful");

                        var testCommand = new SqlCommand("CREATE TABLE TestPermission (id int)", testConnection);
                        await testCommand.ExecuteNonQueryAsync();
                        Console.WriteLine("Test table creation successful");

                        var dropCommand = new SqlCommand("DROP TABLE TestPermission", testConnection);
                        await dropCommand.ExecuteNonQueryAsync();
                        Console.WriteLine("Test table dropped successfully");
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Test connection failed: {ex.Message}");
                    return false;
                }

                using (var connection = new SqlConnection(newDbConnectionString))
                {
                    await connection.OpenAsync();
                    Console.WriteLine("Connected to new database for table creation");

                    var createTablesCommands = new[]
                    {
                        @"CREATE TABLE [Branches] (
                            [BranchID] uniqueidentifier NOT NULL,
                            [BranchName] nvarchar(200) NOT NULL,
                            CONSTRAINT [PK_Branches] PRIMARY KEY ([BranchID])
                        );",

                        @"CREATE TABLE [Vehicles] (
                            [VehicleID] uniqueidentifier NOT NULL,
                            [VehicleName] nvarchar(200) NOT NULL,
                            CONSTRAINT [PK_Vehicles] PRIMARY KEY ([VehicleID])
                        );",

                        @"CREATE TABLE [Staff] (
                            [StaffID] uniqueidentifier NOT NULL,
                            [Name] nvarchar(200) NOT NULL,
                            [Phone] nvarchar(50) NULL,
                            CONSTRAINT [PK_Staff] PRIMARY KEY ([StaffID])
                        );",

                        @"CREATE TABLE [Senders] (
                            [SenderID] uniqueidentifier NOT NULL,
                            [Phone] nvarchar(50) NOT NULL,
                            [Name] nvarchar(200) NOT NULL,
                            [Address] nvarchar(500) NULL,
                            [BranchID] uniqueidentifier NULL,
                            [District] nvarchar(100) NULL,
                            [PickupRequired] bit NOT NULL DEFAULT 0,
                            [PickupStaffID] uniqueidentifier NULL,
                            CONSTRAINT [PK_Senders] PRIMARY KEY ([SenderID]),
                            CONSTRAINT [FK_Senders_Branches_BranchID] FOREIGN KEY ([BranchID]) REFERENCES [Branches] ([BranchID]) ON DELETE SET NULL,
                            CONSTRAINT [FK_Senders_Staff_PickupStaffID] FOREIGN KEY ([PickupStaffID]) REFERENCES [Staff] ([StaffID]) ON DELETE SET NULL
                        );
                        
                        CREATE INDEX [IX_Senders_BranchID] ON [Senders] ([BranchID]);
                        CREATE INDEX [IX_Senders_PickupStaffID] ON [Senders] ([PickupStaffID]);",

                        @"CREATE TABLE [Receivers] (
                            [ReceiverID] uniqueidentifier NOT NULL,
                            [Phone] nvarchar(50) NOT NULL,
                            [Name] nvarchar(200) NOT NULL,
                            [Address] nvarchar(500) NULL,
                            [BranchID] uniqueidentifier NULL,
                            [District] nvarchar(100) NULL,
                            [DeliveryRequired] bit NOT NULL DEFAULT 0,
                            [DeliveryStaffID] uniqueidentifier NULL,
                            CONSTRAINT [PK_Receivers] PRIMARY KEY ([ReceiverID]),
                            CONSTRAINT [FK_Receivers_Branches_BranchID] FOREIGN KEY ([BranchID]) REFERENCES [Branches] ([BranchID]) ON DELETE SET NULL,
                            CONSTRAINT [FK_Receivers_Staff_DeliveryStaffID] FOREIGN KEY ([DeliveryStaffID]) REFERENCES [Staff] ([StaffID]) ON DELETE SET NULL
                        );
                        
                        CREATE INDEX [IX_Receivers_BranchID] ON [Receivers] ([BranchID]);
                        CREATE INDEX [IX_Receivers_DeliveryStaffID] ON [Receivers] ([DeliveryStaffID]);",

                        @"CREATE TABLE [Routes] (
                            [RouteID] uniqueidentifier NOT NULL,
                            [RouteName] nvarchar(200) NOT NULL,
                            [Origin] nvarchar(200) NULL,
                            [Destination] nvarchar(200) NULL,
                            [TransportType] nvarchar(50) NULL,
                            CONSTRAINT [PK_Routes] PRIMARY KEY ([RouteID])
                        );",

                        @"CREATE TABLE [Trips] (
                            [TripID] uniqueidentifier NOT NULL,
                            [RouteID] uniqueidentifier NOT NULL,
                            [VehicleID] uniqueidentifier NULL,
                            [DriverID] uniqueidentifier NULL,
                            [DepartureTime] datetime2 NULL,
                            [ArrivalTime] datetime2 NULL,
                            [Status] nvarchar(50) NULL,
                            CONSTRAINT [PK_Trips] PRIMARY KEY ([TripID]),
                            CONSTRAINT [FK_Trips_Routes_RouteID] FOREIGN KEY ([RouteID]) REFERENCES [Routes] ([RouteID]) ON DELETE NO ACTION,
                            CONSTRAINT [FK_Trips_Vehicles_VehicleID] FOREIGN KEY ([VehicleID]) REFERENCES [Vehicles] ([VehicleID]) ON DELETE SET NULL,
                            CONSTRAINT [FK_Trips_Staff_DriverID] FOREIGN KEY ([DriverID]) REFERENCES [Staff] ([StaffID]) ON DELETE SET NULL
                        );
                        
                        CREATE INDEX [IX_Trips_RouteID] ON [Trips] ([RouteID]);
                        CREATE INDEX [IX_Trips_VehicleID] ON [Trips] ([VehicleID]);
                        CREATE INDEX [IX_Trips_DriverID] ON [Trips] ([DriverID]);",

                        @"CREATE TABLE [Orders] (
                            [OrderID] uniqueidentifier NOT NULL,
                            [OrderDate] datetime2 NOT NULL,
                            [ExpectedDeliveryDate] datetime2 NOT NULL,
                            [OrderType] nvarchar(100) NOT NULL,
                            [TotalValue] decimal(18,2) NOT NULL DEFAULT 0,
                            [Note] nvarchar(max) NULL,
                            [TotalWeight] decimal(18,2) NOT NULL DEFAULT 0,
                            [TotalAmount] decimal(18,2) NOT NULL DEFAULT 0,
                            [Status] nvarchar(50) NOT NULL DEFAULT '',
                            [CreatedDate] datetime2 NOT NULL DEFAULT GETDATE(),
                            [CreatedBy] nvarchar(450) NOT NULL DEFAULT '',
                            [SenderID] uniqueidentifier NULL,
                            [ReceiverID] uniqueidentifier NULL,
                            [RouteID] uniqueidentifier NULL,
                            [TripID] uniqueidentifier NULL,
                            CONSTRAINT [PK_Orders] PRIMARY KEY ([OrderID]),
                            CONSTRAINT [FK_Orders_Senders_SenderID] FOREIGN KEY ([SenderID]) REFERENCES [Senders] ([SenderID]) ON DELETE SET NULL,
                            CONSTRAINT [FK_Orders_Receivers_ReceiverID] FOREIGN KEY ([ReceiverID]) REFERENCES [Receivers] ([ReceiverID]) ON DELETE SET NULL,
                            CONSTRAINT [FK_Orders_Routes_RouteID] FOREIGN KEY ([RouteID]) REFERENCES [Routes] ([RouteID]) ON DELETE SET NULL,
                            CONSTRAINT [FK_Orders_Trips_TripID] FOREIGN KEY ([TripID]) REFERENCES [Trips] ([TripID]) ON DELETE SET NULL
                        );
                        
                        CREATE INDEX [IX_Orders_SenderID] ON [Orders] ([SenderID]);
                        CREATE INDEX [IX_Orders_ReceiverID] ON [Orders] ([ReceiverID]);
                        CREATE INDEX [IX_Orders_RouteID] ON [Orders] ([RouteID]);
                        CREATE INDEX [IX_Orders_TripID] ON [Orders] ([TripID]);
                        CREATE INDEX [IX_Orders_OrderDate] ON [Orders] ([OrderDate]);
                        CREATE INDEX [IX_Orders_CreatedDate] ON [Orders] ([CreatedDate]);",

                        @"CREATE TABLE [OrderItems] (
                            [ItemID] uniqueidentifier NOT NULL,
                            [OrderID] uniqueidentifier NOT NULL,
                            [ItemName] nvarchar(200) NOT NULL,
                            [Unit] nvarchar(50) NULL,
                            [Weight] decimal(18,2) NOT NULL DEFAULT 0,
                            [Quantity] int NOT NULL DEFAULT 0,
                            [Price] decimal(18,2) NOT NULL DEFAULT 0,
                            [Amount] decimal(18,2) NOT NULL DEFAULT 0,
                            CONSTRAINT [PK_OrderItems] PRIMARY KEY ([ItemID]),
                            CONSTRAINT [FK_OrderItems_Orders_OrderID] FOREIGN KEY ([OrderID]) REFERENCES [Orders] ([OrderID]) ON DELETE CASCADE
                        );
                        
                        CREATE INDEX [IX_OrderItems_OrderID] ON [OrderItems] ([OrderID]);",

                        @"CREATE TABLE [Payments] (
                            [PaymentID] uniqueidentifier NOT NULL,
                            [OrderID] uniqueidentifier NOT NULL,
                            [ShippingFee] decimal(18,2) NOT NULL DEFAULT 0,
                            [CODAmount] decimal(18,2) NOT NULL DEFAULT 0,
                            [CODFee] decimal(18,2) NOT NULL DEFAULT 0,
                            [TotalPayment] decimal(18,2) NOT NULL DEFAULT 0,
                            [PaymentMethod] nvarchar(50) NULL,
                            CONSTRAINT [PK_Payments] PRIMARY KEY ([PaymentID]),
                            CONSTRAINT [FK_Payments_Orders_OrderID] FOREIGN KEY ([OrderID]) REFERENCES [Orders] ([OrderID]) ON DELETE CASCADE
                        );
                        
                        CREATE UNIQUE INDEX [IX_Payments_OrderID] ON [Payments] ([OrderID]);"
                    };

                    int successCount = 0;
                    int totalTables = createTablesCommands.Length;

                    foreach (var commandText in createTablesCommands)
                    {
                        try
                        {
                            var command = new SqlCommand(commandText, connection);
                            await command.ExecuteNonQueryAsync();
                            successCount++;
                            Console.WriteLine($"Table {successCount}/{totalTables} created successfully");
                        }
                        catch (Exception ex)
                        {
                            Console.WriteLine($"Failed to create table {successCount + 1}/{totalTables}: {ex.Message}");
                        }
                    }

                    if (successCount == totalTables)
                    {
                        Console.WriteLine("All tables created successfully");
                        return true;
                    }
                    else
                    {
                        Console.WriteLine($"Only {successCount}/{totalTables} tables were created successfully");
                        return false;
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error in CreateTablesInDynamicDatabase: {ex.Message}");
                Console.WriteLine($"Stack trace: {ex.StackTrace}");
                return false;
            }
        }
    }
}
