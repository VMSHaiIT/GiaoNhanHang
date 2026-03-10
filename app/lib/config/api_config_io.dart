import 'dart:io';

String getBaseUrl() {
  if (Platform.isAndroid || Platform.isIOS) {
    return 'http://115.78.95.245:5088/api';
  }
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    return 'http://localhost:5088/api';
  }
  return 'http://115.78.95.245:5088/api';
}
