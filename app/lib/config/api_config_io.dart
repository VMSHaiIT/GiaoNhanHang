import 'dart:io';

import 'package:flutter/foundation.dart';

String getBaseUrl() {
  const String publishBaseUrl = 'https://apitbx.lientinh.com/api';
  if (kReleaseMode) {
    return publishBaseUrl;
  }
  // Android Emulator: 10.0.2.2 trỏ về máy host (localhost của máy dev)
  if (Platform.isAndroid) {
    return 'http://10.0.2.2:5088/api';
  }
  // iOS Simulator / macOS / Windows / Linux → dùng localhost trực tiếp
  if (Platform.isIOS || Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    return 'http://localhost:5088/api';
  }
  return publishBaseUrl;
}
