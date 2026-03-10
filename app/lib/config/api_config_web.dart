String getBaseUrl() {
  // Khi chạy web từ localhost (flutter run -d chrome) thì gọi API local
  final host = Uri.base.host;
  if (host == 'localhost' || host == '127.0.0.1') {
    return 'http://localhost:5088/api';
  }
  return 'http://115.78.95.245:5088/api';
}
