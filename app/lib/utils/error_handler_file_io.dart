import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

const String _logFileName = 'giao_nhan_hang_errors.log';

/// Ghi nội dung lỗi vào file log trong thư mục documents của ứng dụng.
/// Chỉ dùng trên platform có dart:io (mobile, desktop). Web dùng stub.
Future<void> appendErrorToLogFile(String content) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_logFileName');
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final line = '[$timestamp] $content\n';
    await file.writeAsString(line, mode: FileMode.append);
  } catch (_) {
    // Không throw để tránh ảnh hưởng luồng chính khi ghi log lỗi
  }
}
