import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../ui/design_system.dart';
import 'error_handler_file_stub.dart'
    if (dart.library.io) 'error_handler_file_io.dart' as file_logger;

/// Xử lý lỗi: hiển thị thông báo ngắn tiếng Việt cho người dùng,
/// đồng thời ghi log chi tiết (error + stackTrace) cho debug.
class ErrorHandler {
  static const String _logTag = 'AppError';

  /// Hiển thị thông báo lỗi ngắn (tiếng Việt) và ghi log chi tiết.
  /// [context] dùng để hiển thị Flushbar (nếu null thì chỉ log, không hiển thị).
  /// [error] là exception/object lỗi.
  /// [stackTrace] nên truyền khi gọi trong catch (e, st).
  /// [shortMessage] nếu truyền sẽ dùng thay cho message tự động (ví dụ từ API).
  static void show(
    BuildContext? context,
    dynamic error, {
    StackTrace? stackTrace,
    String? shortMessage,
  }) {
    final String userMessage =
        shortMessage ?? _toShortVietnameseMessage(error);
    _logError(error, stackTrace);

    if (context != null && context.mounted) {
      AppWidgets.showFlushbar(context, userMessage, type: MessageType.error);
    }
  }

  /// Chỉ ghi log chi tiết lỗi (không hiển thị UI).
  static void logError(dynamic error, [StackTrace? stackTrace, String? tag]) {
    _logError(error, stackTrace, tag: tag);
  }

  /// Trả về câu thông báo lỗi ngắn tiếng Việt (dùng khi gọi onError callback).
  static String toShortMessage(dynamic error) {
    return _toShortVietnameseMessage(error);
  }

  static void _logError(dynamic error, StackTrace? stackTrace,
      {String? tag}) {
    final String label = tag ?? _logTag;
    developer.log(
      'ERROR: $error',
      name: label,
    );
    if (stackTrace != null) {
      developer.log(
        stackTrace.toString(),
        name: '$label.stack',
      );
    }
    if (kDebugMode) {
      final String fileContent = stackTrace != null
          ? '$error\n$stackTrace'
          : error.toString();
      unawaited(file_logger.appendErrorToLogFile(fileContent));
    }
  }

  /// Chuyển exception sang câu thông báo ngắn tiếng Việt.
  static String _toShortVietnameseMessage(dynamic error) {
    if (error == null) return 'Đã xảy ra lỗi. Vui lòng thử lại.';
    final String msg = error.toString().toLowerCase();
    if (msg.contains('timeout') || msg.contains('timed out')) {
      return 'Hết thời gian chờ. Vui lòng thử lại.';
    }
    if (msg.contains('socket') ||
        msg.contains('connection') ||
        msg.contains('connection refused') ||
        msg.contains('clientexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('network')) {
      return 'Không thể kết nối. Kiểm tra mạng và thử lại.';
    }
    if (msg.contains('401') || msg.contains('unauthorized')) {
      return 'Phiên đăng nhập hết hạn hoặc không hợp lệ.';
    }
    if (msg.contains('403') || msg.contains('forbidden')) {
      return 'Bạn không có quyền thực hiện thao tác này.';
    }
    if (msg.contains('404') || msg.contains('not found')) {
      return 'Không tìm thấy dữ liệu.';
    }
    if (msg.contains('500') ||
        msg.contains('502') ||
        msg.contains('503') ||
        msg.contains('server error')) {
      return 'Lỗi máy chủ. Vui lòng thử lại sau.';
    }
    if (msg.contains('format') ||
        msg.contains('parse') ||
        msg.contains('type') && msg.contains('is not')) {
      return 'Dữ liệu không hợp lệ. Vui lòng thử lại.';
    }
    return 'Đã xảy ra lỗi. Vui lòng thử lại.';
  }
}
