import 'dart:io';

import 'package:flutter/foundation.dart';

String getBaseUrl() {
  const String publishBaseUrl = 'https://apitbx.lientinh.com/api';
  if (kReleaseMode) {
    return publishBaseUrl;
  }
  if (Platform.isAndroid || Platform.isIOS) {
    return 'http://115.78.95.245:5088/api';
  }
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    return 'http://localhost:5088/api';
  }
  return 'http://115.78.95.245:5088/api';
}
