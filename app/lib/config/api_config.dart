import 'api_config_io.dart' if (dart.library.html) 'api_config_web.dart' as _impl;

class ApiConfig {
  static String get baseUrl => _impl.getBaseUrl();
}
