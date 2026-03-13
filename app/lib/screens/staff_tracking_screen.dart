import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_client.dart';
import '../models.dart' as app_models;
import '../ui/design_system.dart';
import '../utils/error_handler.dart';
import '../utils/route_service.dart';
import '../utils/tracking_service.dart';

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
  // ── Service ────────────────────────────────────────────────────────────────
  final _service = TrackingService.instance;

  // ── Trip list state (widget-local) ─────────────────────────────────────────
  List<app_models.Trip> _trips = [];
  bool _isLoadingTrips = true;

  // Bản đồ
  final MapController _mapController = MapController();
  LatLng? _lastMapCenter; // để phát hiện thay đổi vị trí và di chuyển bản đồ

  // Tuyến đường tham khảo
  List<LatLng> _refRoutePoints = [];
  LatLng? _refOriginLatLng;
  LatLng? _refDestLatLng;
  String? _lastRefTripId; // để tránh load lại cùng tuyến

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
    _service.addListener(_onServiceUpdate);
    _loadStaffInfo();
    _loadTrips();
    _searchController.addListener(_filterTrips);
    // Nếu đang tracking nền, tải lại tuyến tham khảo
    if (_service.selectedTrip != null) {
      _loadReferenceRoute(_service.selectedTrip!);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _service.removeListener(_onServiceUpdate);
    _searchController.dispose();
    // ⚠️ KHÔNG gọi stopSharing ở đây — tracking tiếp tục chạy nền
    // khi staff chuyển màn hình. Chỉ dừng khi app bị đóng hoàn toàn.
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      // App bị đóng hoàn toàn → dừng tracking và giải phóng tài nguyên
      _service.forceStop();
    }
    // paused / hidden / inactive → giữ tracking tiếp tục chạy
  }

  /// Callback từ service — rebuild UI và di chuyển bản đồ nếu vị trí thay đổi.
  void _onServiceUpdate() {
    if (!mounted) return;
    setState(() {});

    final pos = _service.currentPosition;
    if (pos != null) {
      final point = LatLng(pos.latitude, pos.longitude);
      if (_lastMapCenter == null ||
          _lastMapCenter!.latitude != pos.latitude ||
          _lastMapCenter!.longitude != pos.longitude) {
        _lastMapCenter = point;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _service.selectedTrip != null) {
            _mapController.move(
              point,
              _service.isSharing ? _mapController.camera.zoom : 15.0,
            );
          }
        });
      }
    }
  }

  // ── Helpers: Load dữ liệu ──────────────────────────────────────────────────
  Future<void> _loadStaffInfo() async {
    final prefs = await SharedPreferences.getInstance();
    // staff_id thường không được lưu trong login → dùng user_login làm fallback
    final id = prefs.getString('staff_id') ??
        prefs.getString('user_login') ??
        prefs.getString('user_email') ??
        '';
    final name = prefs.getString('staff_name') ??
        prefs.getString('user_email') ??
        'Staff';
    setState(() {
      _staffId = id;
      _staffName = name;
    });
    // Cập nhật service với thông tin staff mới nhất
    _service.configure(
      api: widget.api,
      staffId: id,
      staffName: name,
    );
  }

  Future<void> _loadTrips() async {
    setState(() => _isLoadingTrips = true);
    try {
      final trips = await widget.api.getTrips();
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

  Future<void> _loadReferenceRoute(app_models.Trip trip) async {
    final origin = trip.route?.origin;
    final dest = trip.route?.destination;
    if (origin == null || dest == null) return;
    // Bỏ qua nếu đã load cho chuyến này
    if (_lastRefTripId == trip.tripID) return;
    _lastRefTripId = trip.tripID;

    final result = await RouteService.fetchReferenceRoute(origin, dest);
    if (!mounted) return;
    if (_lastRefTripId != trip.tripID) return; // user đã đổi chuyến
    setState(() {
      _refRoutePoints = result.points;
      _refOriginLatLng = result.origin;
      _refDestLatLng = result.destination;
    });

    // Fit bản đồ để thấy cả hai đầu tuyến
    if (result.hasRoute && result.origin != null && result.destination != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds(
              result.origin!,
              result.destination!,
            ),
            padding: const EdgeInsets.all(60),
          ),
        );
      });
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

  // ── Tracking actions (delegate tới service) ────────────────────────────────
  Future<void> _getCurrentLocation() async {
    final ok = await _service.getCurrentLocation();
    if (!ok && mounted) {
      // Nếu bị từ chối vĩnh viễn service không biết hiện thông báo — xử lý ở đây
      if (_service.locationStatus.contains('quyền')) {
        AppWidgets.showFlushbar(
          context,
          'Quyền vị trí bị từ chối. Vui lòng bật trong Cài đặt.',
          type: MessageType.error,
        );
      } else {
        AppWidgets.showFlushbar(context, 'Không lấy được vị trí GPS.',
            type: MessageType.error);
      }
    }
  }

  Future<void> _startSharing() async {
    if (_service.selectedTrip == null) {
      AppWidgets.showFlushbar(context, 'Vui lòng chọn chuyến đi trước.',
          type: MessageType.warning);
      return;
    }
    // Đảm bảo service được cấu hình trước khi bắt đầu
    _service.configure(
      api: widget.api,
      staffId: _staffId,
      staffName: _staffName,
    );
    final error = await _service.startSharing(_service.selectedTrip!);
    if (!mounted) return;
    if (error == null) {
      AppWidgets.showFlushbar(
        context,
        'Đã bắt đầu phát vị trí cho chuyến: '
        '${_service.selectedTrip!.route?.routeName ?? _service.selectedTrip!.tripID}',
        type: MessageType.success,
      );
    } else {
      AppWidgets.showFlushbar(context, 'Không thể bắt đầu phát vị trí: $error',
          type: MessageType.error);
    }
  }

  Future<void> _stopSharing() async {
    await _service.stopSharing();
    if (mounted) {
      AppWidgets.showFlushbar(context, 'Đã dừng phát vị trí.',
          type: MessageType.info);
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
          if (_service.isSharing)
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
      body: _service.selectedTrip == null
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
          _service.selectTrip(trip);
          _getCurrentLocation();
          _loadReferenceRoute(trip);
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
    final trip = _service.selectedTrip!;
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
                  onPressed: _service.currentPosition != null
                      ? () => _mapController.move(
                            LatLng(_service.currentPosition!.latitude,
                                _service.currentPosition!.longitude),
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
            onPressed: _service.isSharing
                ? null
                : () {
                    _service.deselectTrip();
                    setState(() {
                      _refRoutePoints = [];
                      _refOriginLatLng = null;
                      _refDestLatLng = null;
                      _lastRefTripId = null;
                    });
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
    final pos = _service.currentPosition;
    final center = pos != null
        ? LatLng(pos.latitude, pos.longitude)
        : const LatLng(10.7769, 106.7009); // Mặc định TP.HCM

    final markers = <Marker>[];

    // Vị trí hiện tại
    if (pos != null) {
      markers.add(
        Marker(
          point: LatLng(pos.latitude, pos.longitude),
          width: 50,
          height: 50,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_service.isSharing)
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
                  color: _service.isSharing ? Colors.blue : AppTheme.primaryColor,
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

        // Tuyến đường tham khảo (dưới cùng)
        if (_refRoutePoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _refRoutePoints,
                strokeWidth: 3,
                color: Colors.orange.withValues(alpha: 0.65),
                pattern: StrokePattern.dashed(segments: const [12, 6]),
              ),
            ],
          ),

        // Lộ trình đã đi (polyline thực tế)
        if (_service.trackPoints.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _service.trackPoints,
                strokeWidth: 4,
                color: Colors.blue.withValues(alpha: 0.8),
              ),
            ],
          ),

        // Marker điểm xuất phát & điểm đến tham khảo
        if (_refOriginLatLng != null || _refDestLatLng != null)
          MarkerLayer(
            markers: [
              if (_refOriginLatLng != null)
                Marker(
                  point: _refOriginLatLng!,
                  width: 36,
                  height: 42,
                  alignment: Alignment.topCenter,
                  child: _RoutePin(
                    color: Colors.green.shade600,
                    icon: Icons.trip_origin,
                    tooltip: _service.selectedTrip?.route?.origin ?? 'Xuất phát',
                  ),
                ),
              if (_refDestLatLng != null)
                Marker(
                  point: _refDestLatLng!,
                  width: 36,
                  height: 42,
                  alignment: Alignment.topCenter,
                  child: _RoutePin(
                    color: Colors.red.shade600,
                    icon: Icons.location_on,
                    tooltip: _service.selectedTrip?.route?.destination ?? 'Điểm đến',
                  ),
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
                  color: _service.isSharing
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(
                  Icons.gps_fixed,
                  color: _service.isSharing ? Colors.green : Colors.grey,
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
                      _service.isGettingLocation
                          ? 'Đang lấy vị trí...'
                          : _service.locationStatus,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _service.isSharing ? Colors.green[700] : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_service.isSharing && !_service.isGettingLocation)
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
          if (_service.isSharing && _service.trackPoints.isNotEmpty) ...[
            const Divider(height: 1),
            const SizedBox(height: AppTheme.spacingS),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statItem(
                  Icons.timeline,
                  '${_service.trackPoints.length}',
                  'Điểm ghi',
                  Colors.blue,
                ),
                _statItem(
                  Icons.speed,
                  _service.currentPosition?.speed != null
                      ? '${(_service.currentPosition!.speed * 3.6).toStringAsFixed(0)} km/h'
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
            child: _service.isConnecting
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
                : _service.isSharing
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
                        onPressed: _service.currentPosition == null
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

          if (!_service.isSharing && _service.currentPosition == null)
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

// ─────────────────────────────────────────────────────────────────────────────
// Marker ghim điểm xuất phát / điểm đến trên bản đồ
// ─────────────────────────────────────────────────────────────────────────────
class _RoutePin extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String tooltip;

  const _RoutePin({
    required this.color,
    required this.icon,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 15),
          ),
          Positioned(
            bottom: 0,
            child: Container(
              width: 3,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
