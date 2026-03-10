/// Domain web app khi publish (ví dụ: https://tbx.lientinh.com)
const String webAppDomain = 'tbx.lientinh.com';

/// Base URL API production (backend)
const String _apiBaseUrl = 'https://apitbx.lientinh.com/api';

String getBaseUrl() {
  // Khi chạy web từ localhost (flutter run -d chrome) thì gọi API local
  final host = Uri.base.host;
  if (host == 'localhost' || host == '127.0.0.1') {
    return 'http://localhost:5088/api';
  }
  // Khi publish tại tbx.lientinh.com → API tại apitbx.lientinh.com
  return _apiBaseUrl;
}
