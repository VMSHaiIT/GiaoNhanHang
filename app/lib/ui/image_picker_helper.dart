import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'design_system.dart';

/// Helper class để xử lý việc chọn/chụp ảnh từ camera hoặc thư viện
class ImagePickerHelper {
  /// Hiển thị dialog cho người dùng chọn nguồn ảnh (Camera hoặc Gallery)
  /// Trả về ImageSource được chọn hoặc null nếu hủy
  static Future<ImageSource?> showImageSourceDialog(
      BuildContext context) async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Chọn nguồn ảnh',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  title: const Text(
                    'Chụp ảnh',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: const Text('Chụp ảnh mới bằng camera'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.photo_library,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  title: const Text(
                    'Chọn từ thư viện',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: const Text('Chọn ảnh từ thư viện ảnh'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: const Text(
                        'Hủy',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Chọn/chụp ảnh với dialog cho phép chọn nguồn
  /// [maxWidth] và [maxHeight] để resize ảnh (mặc định 1024)
  /// [imageQuality] chất lượng ảnh từ 0-100 (mặc định 90)
  /// Trả về XFile nếu thành công, null nếu hủy hoặc có lỗi
  static Future<XFile?> pickImage({
    required BuildContext context,
    int maxWidth = 1024,
    int maxHeight = 1024,
    int imageQuality = 90,
  }) async {
    try {
      final ImageSource? source = await showImageSourceDialog(context);

      if (source == null) {
        return null;
      }

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: imageQuality,
      );

      return image;
    } catch (e) {
      debugPrint('ImagePickerHelper.pickImage error: $e');
      return null;
    }
  }

  /// Chọn/chụp ảnh và chuyển thành data URL base64
  /// Trả về data URL (data:image/...;base64,...) nếu thành công, null nếu hủy hoặc có lỗi
  static Future<String?> pickAndGetDataUrl({
    required BuildContext context,
    int maxWidth = 1024,
    int maxHeight = 1024,
    int imageQuality = 90,
  }) async {
    try {
      final XFile? image = await pickImage(
        context: context,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final extension = image.path.split('.').last.toLowerCase();
        final mimeType = extension == 'png'
            ? 'png'
            : extension == 'gif'
                ? 'gif'
                : extension == 'webp'
                    ? 'webp'
                    : 'jpeg';
        final base64String = base64Encode(bytes);
        return 'data:image/$mimeType;base64,$base64String';
      }

      return null;
    } catch (e) {
      debugPrint('ImagePickerHelper.pickAndGetDataUrl error: $e');
      String message;
      if (e.toString().contains('permission') ||
          e.toString().contains('Permission')) {
        message =
            'Ứng dụng cần quyền truy cập camera/thư viện ảnh. Vui lòng cấp quyền trong Cài đặt.';
      } else if (e.toString().contains('camera') ||
          e.toString().contains('Camera')) {
        message =
            'Không thể truy cập camera. Vui lòng kiểm tra lại quyền truy cập.';
      } else {
        message = 'Không thể chụp/chọn ảnh';
      }

      if (context.mounted) {
        AppWidgets.showFlushbar(context, message, type: MessageType.error);
      }
      return null;
    }
  }
}
