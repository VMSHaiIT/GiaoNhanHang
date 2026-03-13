import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../api_client.dart';
import '../models.dart' as app_models;
import 'error_handler.dart';

/// Singleton service quản lý phát vị trí GPS theo thời gian thực.
///
/// Tồn tại độc lập với vòng đời của widget — khi staff chuyển màn hình
/// hoặc ẩn ứng dụng, timer và kết nối SignalR vẫn chạy. Trạng thái chỉ
/// bị xóa khi staff bấm "Dừng phát vị trí" hoặc ứng dụng bị đóng hoàn toàn
/// (AppLifecycleState.detached).
class TrackingService extends ChangeNotifier {
  TrackingService._();

  static final TrackingService instance = TrackingService._();

  // ── Public state ───────────────────────────────────────────────────────────
  bool isSharing = false;
  bool isConnecting = false;
  bool isGettingLocation = false;
  app_models.Trip? selectedTrip;
  Position? currentPosition;
  String locationStatus = 'Chưa lấy vị trí';
  final List<LatLng> trackPoints = [];

  // ── Private ────────────────────────────────────────────────────────────────
  HubConnection? _hubConnection;
  Timer? _locationTimer;
  String _staffId = '';
  String _staffName = '';
  ApiClient? _api;

  /// `true` nếu đang kết nối hoặc đang phát — dùng để hiển thị badge.
  bool get isActive => isSharing || isConnecting;

  // ── Configuration ──────────────────────────────────────────────────────────
  /// Gọi từ màn hình mỗi lần khởi tạo để đảm bảo API và thông tin staff
  /// luôn được cập nhật ngay cả khi màn hình bị tái tạo.
  void configure({
    required ApiClient api,
    required String staffId,
    required String staffName,
  }) {
    _api = api;
    _staffId = staffId;
    _staffName = staffName;
  }

  // ── Permission & Location ──────────────────────────────────────────────────
  Future<bool> checkAndRequestPermission() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  /// Lấy vị trí hiện tại một lần. Trả về `true` nếu thành công.
  Future<bool> getCurrentLocation() async {
    isGettingLocation = true;
    locationStatus = 'Đang lấy vị trí...';
    notifyListeners();
    try {
      final hasPerm = await checkAndRequestPermission();
      if (!hasPerm) {
        locationStatus = 'Không có quyền truy cập vị trí';
        isGettingLocation = false;
        notifyListeners();
        return false;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      currentPosition = pos;
      locationStatus =
          '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      isGettingLocation = false;
      notifyListeners();
      return true;
    } catch (e) {
      locationStatus = 'Lỗi: ${e.toString()}';
      currentPosition = null;
      isGettingLocation = false;
      notifyListeners();
      return false;
    }
  }

  // ── Trip selection ─────────────────────────────────────────────────────────
  void selectTrip(app_models.Trip trip) {
    selectedTrip = trip;
    notifyListeners();
  }

  void deselectTrip() {
    if (!isSharing && !isConnecting) {
      selectedTrip = null;
      notifyListeners();
    }
  }

  // ── SignalR ────────────────────────────────────────────────────────────────
  Future<void> _connectSignalR() async {
    if (_api == null) return;
    try {
      final token = await _api!.getAuthToken();
      final baseUrl = _api!.baseUrl.replaceAll('/api', '');

      final connection = HubConnectionBuilder()
          .withUrl(
            '$baseUrl/locationHub',
            options: HttpConnectionOptions(
              accessTokenFactory: () async => token,
              skipNegotiation: false,
              transport: HttpTransportType.WebSockets,
            ),
          )
          .withAutomaticReconnect(retryDelays: [2000, 5000, 10000, 30000])
          .build();

      connection.onclose(({Exception? error}) {
        if (isSharing) {
          locationStatus = 'Mất kết nối SignalR, đang thử lại...';
          notifyListeners();
        }
      });

      connection.onreconnecting(({Exception? error}) {
        locationStatus = 'Đang kết nối lại...';
        notifyListeners();
      });

      connection.onreconnected(({String? connectionId}) {
        locationStatus = 'Đã kết nối lại';
        notifyListeners();
      });

      await connection.start();
      _hubConnection = connection;
    } catch (e) {
      _hubConnection = null;
      ErrorHandler.logError(e, null, 'SignalR');
      // Fallback: sẽ dùng REST polling trong _sendCurrentLocation
    }
  }

  // ── Start sharing ──────────────────────────────────────────────────────────
  /// Bắt đầu phát vị trí cho [trip]. Trả về `null` nếu thành công,
  /// hoặc chuỗi mô tả lỗi nếu thất bại.
  Future<String?> startSharing(app_models.Trip trip) async {
    if (_api == null) return 'Chưa cấu hình API';

    final hasPerm = await checkAndRequestPermission();
    if (!hasPerm) return 'Không có quyền GPS';

    isConnecting = true;
    notifyListeners();

    try {
      // 1. Lấy vị trí ban đầu
      final gotLoc = await getCurrentLocation();
      if (!gotLoc) {
        isConnecting = false;
        notifyListeners();
        return 'Không lấy được vị trí GPS';
      }

      // 2. Ghi nhận chuyến đi
      selectedTrip = trip;

      // 3. Kết nối SignalR
      await _connectSignalR();

      // 4. Cập nhật trạng thái
      isSharing = true;
      isConnecting = false;
      trackPoints.clear();
      locationStatus = 'Đang phát vị trí...';
      notifyListeners();

      // 5. Gửi ngay lập tức, rồi bắt đầu timer mỗi 5 giây
      await _sendCurrentLocation();
      _locationTimer?.cancel();
      _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _sendCurrentLocation();
      });

      return null; // success
    } catch (e, st) {
      isConnecting = false;
      notifyListeners();
      ErrorHandler.logError(e, st, 'StartSharing');
      return e.toString();
    }
  }

  // ── Send location ──────────────────────────────────────────────────────────
  Future<void> _sendCurrentLocation() async {
    if (_api == null || selectedTrip == null) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      final point = LatLng(pos.latitude, pos.longitude);
      currentPosition = pos;
      trackPoints.add(point);
      locationStatus =
          '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}'
          '${pos.speed > 0 ? '  ${(pos.speed * 3.6).toStringAsFixed(1)} km/h' : ''}';
      notifyListeners();

      final dto = app_models.StaffLocationDto(
        staffID: _staffId,
        staffName: _staffName,
        tripID: selectedTrip!.tripID,
        latitude: pos.latitude,
        longitude: pos.longitude,
        speedKmh: pos.speed >= 0 ? pos.speed * 3.6 : null,
        heading: pos.heading >= 0 ? pos.heading : null,
        timestamp: DateTime.now(),
      );

      // Ưu tiên SignalR, fallback REST
      if (_hubConnection?.state == HubConnectionState.Connected) {
        await _hubConnection!.invoke('SendLocation', args: [dto.toJson()]);
      } else {
        await _api!.updateLocation(
          app_models.LocationUpdateRequest(
            staffID: _staffId,
            staffName: _staffName,
            tripID: selectedTrip!.tripID,
            latitude: pos.latitude,
            longitude: pos.longitude,
            speedKmh: dto.speedKmh,
            heading: dto.heading,
          ),
        );
      }
    } catch (e) {
      ErrorHandler.logError(e, null, 'SendLocation');
    }
  }

  // ── Stop sharing ───────────────────────────────────────────────────────────
  Future<void> stopSharing() async {
    _locationTimer?.cancel();
    _locationTimer = null;

    try {
      if (_hubConnection?.state == HubConnectionState.Connected &&
          selectedTrip != null) {
        await _hubConnection!.invoke(
          'StopSharing',
          args: [_staffId, selectedTrip!.tripID],
        );
      }
      if (selectedTrip != null && _staffId.isNotEmpty && _api != null) {
        await _api!.stopLocationSharing(
          app_models.LocationStopRequest(
            staffID: _staffId,
            tripID: selectedTrip!.tripID,
          ),
        );
      }
    } catch (e) {
      ErrorHandler.logError(e, null, 'StopSharing');
    }

    await _hubConnection?.stop();
    _hubConnection = null;

    isSharing = false;
    locationStatus = 'Đã dừng phát vị trí';
    notifyListeners();
  }

  // ── Force stop (app bị đóng hoàn toàn) ────────────────────────────────────
  /// Dừng ngay lập tức không gửi thông báo lên server (dùng khi app bị kill).
  Future<void> forceStop() async {
    _locationTimer?.cancel();
    _locationTimer = null;
    try {
      _hubConnection?.stop().ignore();
    } catch (_) {}
    _hubConnection = null;
    isSharing = false;
    isConnecting = false;
    isGettingLocation = false;
    selectedTrip = null;
    trackPoints.clear();
    locationStatus = 'Chưa lấy vị trí';
    currentPosition = null;
    notifyListeners();
  }
}
