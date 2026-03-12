import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../api_client.dart';
import '../models.dart' as app_models;
import '../ui/design_system.dart';
import '../utils/error_handler.dart';

/// Màn hình phát vị trí thời gian thực dành cho Staff.
/// Luồng: Chọn chuyến đi → Xem bản đồ + vị trí hiện tại → Bật phát vị trí
class StaffTrackingScreen extends StatefulWidget {
  final ApiClient api;
  const StaffTrackingScreen({super.key, required this.api});

  @override
  State<StaffTrackingScreen> createState() => _StaffTrackingScreenState();
}

class _StaffTrackingScreenState extends State<StaffTrackingScreen>
    with WidgetsBindingObserver {
  // ── State ──────────────────────────────────────────────────────────────────
  List<app_models.Trip> _trips = [];
  app_models.Trip? _selectedTrip;
  bool _isLoadingTrips = true;
  bool _isSharing = false;
  bool _isConnecting = false;

  // Vị trí hiện tại
  Position? _currentPosition;
  bool _isGettingLocation = false;
  String _locationStatus = 'Chưa lấy vị trí';

  // Bản đồ
  final MapController _mapController = MapController();
  final List<LatLng> _trackPoints = []; // lộ trình đã đi

  // SignalR
  HubConnection? _hubConnection;
  Timer? _locationTimer;

  // Thông tin staff
  String _staffId = '';
  String _staffName = '';

  // Lọc chuyến
  final _searchController = TextEditingController();
  List<app_models.Trip> _filteredTrips = [];

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStaffInfo();
    _loadTrips();
    _searchController.addListener(_filterTrips);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _stopSharing(silent: true);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Dừng chia sẻ khi app vào background (tuỳ chọn, có thể bỏ)
    if (state == AppLifecycleState.paused && _isSharing) {
      // Giữ chia sẻ khi background — không dừng
    }
  }

  // ── Helpers: Load dữ liệu ──────────────────────────────────────────────────
  Future<void> _loadStaffInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _staffId = prefs.getString('staff_id') ?? '';
      _staffName = prefs.getString('staff_name') ??
          prefs.getString('user_email') ??
          'Staff';
    });
  }

  Future<void> _loadTrips() async {
    setState(() => _isLoadingTrips = true);
    try {
      final trips = await widget.api.getTrips();
      // Lọc chuyến đang hoạt động hoặc chờ — staff chỉ thấy chuyến liên quan
      final active = trips
          .where((t) => t.status == 'Đang chạy' || t.status == 'Chờ')
          .toList();
      setState(() {
        _trips = active;
        _filteredTrips = List.from(active);
      });
    } catch (e, st) {
      if (mounted) {
        ErrorHandler.show(context, e,
            stackTrace: st,
            shortMessage: 'Không tải được danh sách chuyến đi.');
      }
    } finally {
      setState(() => _isLoadingTrips = false);
    }
  }

  void _filterTrips() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredTrips = List.from(_trips);
      } else {
        _filteredTrips = _trips.where((t) {
          final name = t.route?.routeName.toLowerCase() ?? '';
          final origin = t.route?.origin.toLowerCase() ?? '';
          final dest = t.route?.destination.toLowerCase() ?? '';
          final status = t.status.toLowerCase();
          return name.contains(q) ||
              origin.contains(q) ||
              dest.contains(q) ||
              status.contains(q);
        }).toList();
      }
    });
  }

  // ── GPS Permission & Position ──────────────────────────────────────────────
  Future<bool> _checkAndRequestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        AppWidgets.showFlushbar(
          context,
          'Quyền vị trí bị từ chối vĩnh viễn. Vui lòng bật trong Cài đặt.',
          type: MessageType.error,
        );
      }
      return false;
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
      _locationStatus = 'Đang lấy vị trí...';
    });
    try {
      final hasPermission = await _checkAndRequestPermission();
      if (!hasPermission) {
        setState(() => _locationStatus = 'Không có quyền truy cập vị trí');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      setState(() {
        _currentPosition = pos;
        _locationStatus =
            '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      });
      _mapController.move(
        LatLng(pos.latitude, pos.longitude),
        15.0,
      );
    } catch (e) {
      setState(() => _locationStatus = 'Lỗi: ${e.toString()}');
      if (mounted) {
        AppWidgets.showFlushbar(context, 'Không lấy được vị trí GPS.',
            type: MessageType.error);
      }
    } finally {
      setState(() => _isGettingLocation = false);
    }
  }

  // ── SignalR ────────────────────────────────────────────────────────────────
  Future<void> _connectSignalR() async {
    try {
      final token = await widget.api.getAuthToken();
      final baseUrl = widget.api.baseUrl
          .replaceAll('/api', ''); // https://apitbx.lientinh.com

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
        if (mounted && _isSharing) {
          setState(() => _locationStatus = 'Mất kết nối SignalR, đang thử lại...');
        }
      });

      connection.onreconnecting(({Exception? error}) {
        if (mounted) {
          setState(() => _locationStatus = 'Đang kết nối lại...');
        }
      });

      connection.onreconnected(({String? connectionId}) {
        if (mounted) {
          setState(() => _locationStatus = 'Đã kết nối lại');
        }
      });

      await connection.start();
      _hubConnection = connection;
    } catch (e) {
      _hubConnection = null;
      ErrorHandler.logError(e, null, 'SignalR');
      // Fallback: dùng REST polling
    }
  }

  // ── Bắt đầu phát vị trí ───────────────────────────────────────────────────
  Future<void> _startSharing() async {
    if (_selectedTrip == null) {
      AppWidgets.showFlushbar(context, 'Vui lòng chọn chuyến đi trước.',
          type: MessageType.warning);
      return;
    }

    final hasPermission = await _checkAndRequestPermission();
    if (!hasPermission) return;

    setState(() => _isConnecting = true);

    try {
      // 1. Lấy vị trí ban đầu
      await _getCurrentLocation();
      if (_currentPosition == null) {
        setState(() => _isConnecting = false);
        return;
      }

      // 2. Kết nối SignalR
      await _connectSignalR();

      // 3. Bắt đầu timer gửi vị trí mỗi 5 giây
      setState(() {
        _isSharing = true;
        _isConnecting = false;
        _trackPoints.clear();
        _locationStatus = 'Đang phát vị trí...';
      });

      _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _sendCurrentLocation();
      });

      // Gửi ngay lập tức lần đầu
      _sendCurrentLocation();

      if (mounted) {
        AppWidgets.showFlushbar(
          context,
          'Đã bắt đầu phát vị trí cho chuyến: ${_selectedTrip!.route?.routeName ?? _selectedTrip!.tripID}',
          type: MessageType.success,
        );
      }
    } catch (e, st) {
      setState(() => _isConnecting = false);
      if (mounted) {
        ErrorHandler.show(context, e, stackTrace: st,
            shortMessage: 'Không thể bắt đầu phát vị trí.');
      }
    }
  }

  Future<void> _sendCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      if (!mounted) return;

      final point = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _currentPosition = pos;
        _trackPoints.add(point);
        _locationStatus =
            '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}  '
            '${pos.speed > 0 ? '${(pos.speed * 3.6).toStringAsFixed(1)} km/h' : ''}';
      });

      // Di chuyển bản đồ theo
      _mapController.move(point, _mapController.camera.zoom);

      final dto = app_models.StaffLocationDto(
        staffID: _staffId,
        staffName: _staffName,
        tripID: _selectedTrip!.tripID,
        latitude: pos.latitude,
        longitude: pos.longitude,
        speedKmh: pos.speed >= 0 ? pos.speed * 3.6 : null,
        heading: pos.heading >= 0 ? pos.heading : null,
        timestamp: DateTime.now(),
      );

      // Ưu tiên SignalR
      if (_hubConnection?.state == HubConnectionState.Connected) {
        await _hubConnection!.invoke('SendLocation', args: [dto.toJson()]);
      } else {
        // Fallback REST
        await widget.api.updateLocation(
          app_models.LocationUpdateRequest(
            staffID: _staffId,
            tripID: _selectedTrip!.tripID,
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

  // ── Dừng phát vị trí ──────────────────────────────────────────────────────
  Future<void> _stopSharing({bool silent = false}) async {
    _locationTimer?.cancel();
    _locationTimer = null;

    try {
      if (_hubConnection?.state == HubConnectionState.Connected &&
          _selectedTrip != null) {
        await _hubConnection!.invoke(
          'StopSharing',
          args: [_staffId, _selectedTrip!.tripID],
        );
      }

      if (_selectedTrip != null && _staffId.isNotEmpty) {
        await widget.api.stopLocationSharing(
          app_models.LocationStopRequest(
            staffID: _staffId,
            tripID: _selectedTrip!.tripID,
          ),
        );
      }
    } catch (e) {
      ErrorHandler.logError(e, null, 'StopSharing');
    }

    await _hubConnection?.stop();
    _hubConnection = null;

    if (mounted) {
      setState(() {
        _isSharing = false;
        _locationStatus = 'Đã dừng phát vị trí';
      });
      if (!silent) {
        AppWidgets.showFlushbar(context, 'Đã dừng phát vị trí.',
            type: MessageType.info);
      }
    }
  }

  // ── UI Helper ─────────────────────────────────────────────────────────────
  String _formatTripTime(DateTime? dt) {
    if (dt == null) return '--';
    return DateFormat('dd/MM HH:mm').format(dt.toLocal());
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Đang chạy':
        return Colors.green;
      case 'Chờ':
        return Colors.orange;
      case 'Hoàn thành':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceAlt,
      appBar: AppBar(
        title: const Text('Phát vị trí - Chuyến đi'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_isSharing)
            Padding(
              padding: const EdgeInsets.only(right: AppTheme.spacingS),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: _selectedTrip == null
          ? _buildTripSelector()
          : _buildTrackingView(),
    );
  }

  // ── Panel chọn chuyến ─────────────────────────────────────────────────────
  Widget _buildTripSelector() {
    return Column(
      children: [
        // Header
        Container(
          color: AppTheme.primaryColor,
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacingM,
            0,
            AppTheme.spacingM,
            AppTheme.spacingM,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chọn chuyến đi của bạn',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Tìm theo tuyến, điểm đi, điểm đến...',
                  hintStyle: const TextStyle(color: Colors.white60),
                  prefixIcon: const Icon(Icons.search, color: Colors.white60),
                  filled: true,
                  fillColor: Colors.white12,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMedium),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: AppTheme.spacingS,
                    horizontal: AppTheme.spacingM,
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),

        // Danh sách chuyến
        Expanded(
          child: _isLoadingTrips
              ? const Center(child: CircularProgressIndicator())
              : _filteredTrips.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadTrips,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(AppTheme.spacingM),
                        itemCount: _filteredTrips.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppTheme.spacingS),
                        itemBuilder: (context, index) {
                          return _buildTripCard(_filteredTrips[index]);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_bus_outlined,
              size: 64, color: Colors.grey[400]),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            'Không có chuyến đi nào',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'Chỉ hiển thị chuyến "Chờ" và "Đang chạy"',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
          const SizedBox(height: AppTheme.spacingL),
          OutlinedButton.icon(
            onPressed: _loadTrips,
            icon: const Icon(Icons.refresh),
            label: const Text('Tải lại'),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(app_models.Trip trip) {
    final route = trip.route;
    final statusColor = _statusColor(trip.status);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        onTap: () {
          setState(() => _selectedTrip = trip);
          _getCurrentLocation();
        },
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row: Route name + Status badge
              Row(
                children: [
                  const Icon(Icons.route, size: 20, color: AppTheme.primaryColor),
                  const SizedBox(width: AppTheme.spacingXS),
                  Expanded(
                    child: Text(
                      route?.routeName ?? 'Tuyến không xác định',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      trip.status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingS),

              // Origin → Destination
              if (route != null) ...[
                Row(
                  children: [
                    const Icon(Icons.radio_button_checked,
                        size: 16, color: Colors.green),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        route.origin,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 7),
                  child: SizedBox(
                    height: 14,
                    child: VerticalDivider(
                        color: Colors.grey.shade400, thickness: 1),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        size: 16, color: Colors.red),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        route.destination,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: AppTheme.spacingS),
              const Divider(height: 1),
              const SizedBox(height: AppTheme.spacingS),

              // Info row
              Row(
                children: [
                  _infoChip(
                    Icons.schedule,
                    _formatTripTime(trip.departureTime),
                    Colors.blue,
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  if (trip.vehicle != null)
                    _infoChip(
                      Icons.local_shipping,
                      trip.vehicle!.vehicleName,
                      Colors.orange,
                    ),
                  const Spacer(),
                  const Icon(Icons.chevron_right,
                      color: AppTheme.primaryColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }

  // ── Map + Tracking View ────────────────────────────────────────────────────
  Widget _buildTrackingView() {
    final trip = _selectedTrip!;
    final route = trip.route;

    return Column(
      children: [
        // Trip info banner
        _buildTripBanner(trip, route),

        // Map
        Expanded(
          child: Stack(
            children: [
              _buildMap(),
              // Overlay: thông tin vị trí
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildControlPanel(),
              ),
              // Nút định vị lại
              Positioned(
                right: AppTheme.spacingM,
                bottom: 200,
                child: FloatingActionButton.small(
                  heroTag: 'locate',
                  onPressed: _currentPosition != null
                      ? () => _mapController.move(
                            LatLng(_currentPosition!.latitude,
                                _currentPosition!.longitude),
                            16,
                          )
                      : _getCurrentLocation,
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primaryColor,
                  child: const Icon(Icons.my_location),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTripBanner(
      app_models.Trip trip, app_models.Route? route) {
    return Container(
      color: AppTheme.primaryColor,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      child: Row(
        children: [
          const Icon(Icons.route, color: Colors.white70, size: 18),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  route?.routeName ?? 'Chuyến ${trip.tripID.substring(0, 8)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (route != null)
                  Text(
                    '${route.origin}  →  ${route.destination}',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12),
                  ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _isSharing
                ? null
                : () {
                    setState(() => _selectedTrip = null);
                    _stopSharing(silent: true);
                  },
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Đổi'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final center = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : const LatLng(10.7769, 106.7009); // Mặc định TP.HCM

    final markers = <Marker>[];

    // Vị trí hiện tại
    if (_currentPosition != null) {
      markers.add(
        Marker(
          point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          width: 50,
          height: 50,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_isSharing)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.withValues(alpha: 0.2),
                  ),
                ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _isSharing ? Colors.blue : AppTheme.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Icon(Icons.navigation,
                    color: Colors.white, size: 12),
              ),
            ],
          ),
        ),
      );
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 14.0,
        minZoom: 5,
        maxZoom: 18,
      ),
      children: [
        // Tile layer (OpenStreetMap - miễn phí)
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.giao_nhan_hang',
          maxZoom: 18,
        ),

        // Lộ trình đã đi (polyline)
        if (_trackPoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _trackPoints,
                strokeWidth: 4,
                color: Colors.blue.withValues(alpha: 0.8),
              ),
            ],
          ),

        // Marker vị trí hiện tại
        MarkerLayer(markers: markers),
      ],
    );
  }

  Widget _buildControlPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),

          // Vị trí GPS
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isSharing
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(
                  Icons.gps_fixed,
                  color: _isSharing ? Colors.green : Colors.grey,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vị trí GPS',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      _isGettingLocation
                          ? 'Đang lấy vị trí...'
                          : _locationStatus,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _isSharing ? Colors.green[700] : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_isSharing && !_isGettingLocation)
                TextButton.icon(
                  onPressed: _getCurrentLocation,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Cập nhật'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    padding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),

          const SizedBox(height: AppTheme.spacingS),

          // Thống kê (khi đang chia sẻ)
          if (_isSharing && _trackPoints.isNotEmpty) ...[
            const Divider(height: 1),
            const SizedBox(height: AppTheme.spacingS),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statItem(
                  Icons.timeline,
                  '${_trackPoints.length}',
                  'Điểm ghi',
                  Colors.blue,
                ),
                _statItem(
                  Icons.speed,
                  _currentPosition?.speed != null
                      ? '${(_currentPosition!.speed * 3.6).toStringAsFixed(0)} km/h'
                      : '--',
                  'Tốc độ',
                  Colors.orange,
                ),
                _statItem(
                  Icons.access_time,
                  DateFormat('HH:mm:ss').format(DateTime.now()),
                  'Thời gian',
                  Colors.purple,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingS),
          ],

          const SizedBox(height: AppTheme.spacingS),

          // Nút bật/tắt
          SizedBox(
            width: double.infinity,
            height: AppTheme.controlHeight,
            child: _isConnecting
                ? const ElevatedButton(
                    onPressed: null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Đang kết nối...'),
                      ],
                    ),
                  )
                : _isSharing
                    ? ElevatedButton.icon(
                        onPressed: () => _stopSharing(),
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text(
                          'Dừng phát vị trí',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMedium),
                          ),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: _currentPosition == null
                            ? null
                            : _startSharing,
                        icon: const Icon(Icons.location_on),
                        label: const Text(
                          'Bật phát vị trí',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMedium),
                          ),
                          disabledBackgroundColor:
                              AppTheme.primaryColor.withValues(alpha: 0.4),
                        ),
                      ),
          ),

          if (!_isSharing && _currentPosition == null)
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.spacingS),
              child: Text(
                'Cần lấy vị trí GPS trước khi bật',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statItem(
      IconData icon, String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
