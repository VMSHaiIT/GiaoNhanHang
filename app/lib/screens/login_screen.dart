import 'package:flutter/material.dart';
import '../api_client.dart';
import '../models.dart';
import '../ui/design_system.dart';
import '../utils/error_handler.dart';

class LoginScreen extends StatefulWidget {
  final ApiClient api;
  final VoidCallback onLoginSuccess;

  const LoginScreen({
    super.key,
    required this.api,
    required this.onLoginSuccess,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _userLoginController = TextEditingController();
  final _passwordLoginController = TextEditingController();

  bool _isLoading = false;
  String _currentStep = 'email'; // 'email', 'login', 'create_account'
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onEmailChanged);
    _userLoginController.addListener(_onUserLoginChanged);
  }

  void _onEmailChanged() {
    final email = _emailController.text;
    setState(() {
      _userLoginController.text = email.toLowerCase();
    });
  }

  void _onUserLoginChanged() {
    final userLogin = _userLoginController.text;
    if (userLogin != userLogin.toLowerCase()) {
      _userLoginController.value = _userLoginController.value.copyWith(
        text: userLogin.toLowerCase(),
        selection:
            TextSelection.collapsed(offset: userLogin.toLowerCase().length),
      );
    }
  }

  @override
  void dispose() {
    _emailController.removeListener(_onEmailChanged);
    _userLoginController.removeListener(_onUserLoginChanged);
    _emailController.dispose();
    _userLoginController.dispose();
    _passwordLoginController.dispose();
    super.dispose();
  }

  Future<void> _checkEmail() async {
    if (_emailController.text.trim().isEmpty) {
      AppWidgets.showFlushbar(context, 'Vui lòng nhập email/tên shop',
          type: MessageType.warning);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final shopName = _emailController.text.trim().toLowerCase();
      final response = await widget.api.checkEmail(shopName);

      setState(() {
        if (response.exists) {
          _currentStep = 'login';
        } else {
          _currentStep = 'create_account';
        }
      });

      if (mounted) {
        if (response.exists) {
          AppWidgets.showFlushbar(
            context,
            'Chào mừng trở lại: ${_emailController.text.trim()}!',
            type: MessageType.success,
          );
        } else {
          AppWidgets.showFlushbar(context, response.message,
              type: MessageType.info);
        }
      }
    } catch (e, st) {
      if (mounted) {
        ErrorHandler.show(context, e, stackTrace: st,
            shortMessage: 'Không thể kết nối. Kiểm tra mạng hoặc API.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final request = LoginRequest(
        email: _emailController.text.trim().toLowerCase(),
        userLogin: _userLoginController.text.trim().toLowerCase(),
        passwordLogin: _passwordLoginController.text,
      );

      final response = await widget.api.login(request);

      if (response.success) {
        if (mounted) {
          AppWidgets.showFlushbar(context, response.message,
              type: MessageType.success);
        }
        widget.onLoginSuccess();
      } else {
        if (mounted) {
          AppWidgets.showFlushbar(context, response.message,
              type: MessageType.error);
        }
      }
    } catch (e, st) {
      if (mounted) {
        ErrorHandler.show(context, e, stackTrace: st,
            shortMessage: 'Đăng nhập thất bại. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _goBack() {
    setState(() {
      _currentStep = 'email';
      _passwordLoginController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceAlt,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingXL),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo/Title
                    const Icon(
                      Icons.local_shipping,
                      size: 80,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(height: AppTheme.spacingL),
                    const Text(
                      'Giao Nhận Hàng',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.spacingXL),

                    // Email/Shop Name Input
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email/Tên shop',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMedium),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      enabled: _currentStep == 'email' && !_isLoading,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập email/tên shop';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingM),

                    // Check Email Button
                    if (_currentStep == 'email')
                      ElevatedButton(
                        onPressed: _isLoading ? null : _checkEmail,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: AppTheme.spacingM),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMedium),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text('Kiểm tra'),
                      ),

                    // Login/Create Account Form
                    if (_currentStep == 'login' ||
                        _currentStep == 'create_account') ...[
                      TextFormField(
                        controller: _userLoginController,
                        decoration: InputDecoration(
                          labelText: 'Tên đăng nhập database',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMedium),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        enabled: !_isLoading,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Vui lòng nhập tên đăng nhập';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      TextFormField(
                        controller: _passwordLoginController,
                        decoration: InputDecoration(
                          labelText: 'Mật khẩu database',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(_isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMedium),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        obscureText: !_isPasswordVisible,
                        enabled: !_isLoading,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Vui lòng nhập mật khẩu';
                          }
                          if (_currentStep == 'create_account' &&
                              value.length < 8) {
                            return 'Mật khẩu phải có ít nhất 8 ký tự';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppTheme.spacingL),
                      Row(
                        children: [
                          TextButton(
                            onPressed: _isLoading ? null : _goBack,
                            child: const Text('Quay lại'),
                          ),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spacingXL,
                                  vertical: AppTheme.spacingM),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMedium),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : Text(_currentStep == 'login'
                                    ? 'Đăng nhập'
                                    : 'Tạo tài khoản'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
