import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../api_client.dart';
import '../models.dart' as app_models;
import '../ui/design_system.dart';
import '../utils/error_handler.dart';
import '../utils/route_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point widget
// ─────────────────────────────────────────────────────────────────────────────
class OrderTrackingScreen extends StatefulWidget {
  final ApiClient api;
  const OrderTrackingScreen({super.key, required this.api});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  List<app_models.Order> _orders = [];
  List<app_models.Order> _filtered = [];
  bool _isLoading = true;
  String _selectedStatus = 'Tất cả';
  final _searchCtrl = TextEditingController();

  static const _statuses = [
    'Tất cả',
    'Chờ xử lý',
    'Đang vận chuyển',
    'Hoàn thành',
    'Hủy',
  ];

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final orders = await widget.api.getOrders();
      setState(() {
        _orders = orders;
        _filter();
      });
    } catch (e, st) {
      if (mounted) {
        ErrorHandler.show(context, e,
            stackTrace: st,
            shortMessage: 'Không tải được danh sách đơn hàng.');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = _orders.where((o) {
        final matchStatus =
            _selectedStatus == 'Tất cả' || o.status == _selectedStatus;
        if (!matchStatus) return false;
        if (q.isEmpty) return true;
        return o.orderID.toLowerCase().contains(q) ||
            (o.sender?.name.toLowerCase().contains(q) ?? false) ||
            (o.receiver?.name.toLowerCase().contains(q) ?? false) ||
            (o.route?.routeName.toLowerCase().contains(q) ?? false) ||
            o.status.toLowerCase().contains(q);
      }).toList();
    });
  }

  void _openDetail(app_models.Order order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _OrderDetailPage(api: widget.api, order: order),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceAlt,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _loadOrders,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                              AppTheme.spacingM, AppTheme.spacingS,
                              AppTheme.spacingM, AppTheme.spacingL),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppTheme.spacingS),
                          itemBuilder: (_, i) =>
                              _OrderCard(order: _filtered[i], onTap: () => _openDetail(_filtered[i])),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppTheme.primaryColor,
      padding: const EdgeInsets.fromLTRB(
          AppTheme.spacingM, AppTheme.spacingM, AppTheme.spacingM, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Theo dõi đơn hàng',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          // Search
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Tìm theo mã đơn, người gửi, người nhận...',
              hintStyle: const TextStyle(color: Colors.white60),
              prefixIcon: const Icon(Icons.search, color: Colors.white60),
              filled: true,
              fillColor: Colors.white12,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  vertical: AppTheme.spacingS, horizontal: AppTheme.spacingM),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: AppTheme.spacingS),
          // Status filter chips
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _statuses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final s = _statuses[i];
                final selected = s == _selectedStatus;
                return ChoiceChip(
                  label: Text(s,
                      style: TextStyle(
                        fontSize: 12,
                        color: selected ? Colors.white : Colors.white70,
                      )),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _selectedStatus = s);
                    _filter();
                  },
                  selectedColor: Colors.white24,
                  backgroundColor: Colors.transparent,
                  side: BorderSide(
                    color: selected ? Colors.white : Colors.white38,
                  ),
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                );
              },
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: AppTheme.spacingM),
          Text(
            _orders.isEmpty
                ? 'Chưa có đơn hàng nào'
                : 'Không tìm thấy đơn hàng',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: AppTheme.spacingL),
          OutlinedButton.icon(
            onPressed: _loadOrders,
            icon: const Icon(Icons.refresh),
            label: const Text('Tải lại'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Order list card
// ─────────────────────────────────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final app_models.Order order;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.onTap});

  Color _statusColor(String s) {
    switch (s) {
      case 'Đang vận chuyển':
        return Colors.blue;
      case 'Hoàn thành':
        return Colors.green;
      case 'Hủy':
        return Colors.red;
      case 'Chờ xử lý':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'Đang vận chuyển':
        return Icons.local_shipping;
      case 'Hoàn thành':
        return Icons.check_circle;
      case 'Hủy':
        return Icons.cancel;
      default:
        return Icons.hourglass_top;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor(order.status);
    final fmt = DateFormat('dd/MM/yyyy');
    final hasTrip = order.tripID != null && order.tripID!.isNotEmpty;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row: order ID + status
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Text(
                      '#${order.orderID.length > 8 ? order.orderID.substring(0, 8).toUpperCase() : order.orderID.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  if (hasTrip)
                    Tooltip(
                      message: 'Đã gán chuyến',
                      child: Icon(Icons.route,
                          size: 14, color: Colors.green.shade600),
                    ),
                  const Spacer(),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: sc.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: sc.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_statusIcon(order.status),
                            size: 12, color: sc),
                        const SizedBox(width: 4),
                        Text(
                          order.status,
                          style: TextStyle(
                              fontSize: 11,
                              color: sc,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingS),

              // Sender → Receiver
              Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 14, color: Colors.green),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.sender?.name ?? 'Người gửi không xác định',
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward,
                        size: 14, color: Colors.grey),
                  ),
                  const Icon(Icons.person_pin_outlined,
                      size: 14, color: Colors.red),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.receiver?.name ?? 'Người nhận không xác định',
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingXS),

              // Route
              if (order.route != null)
                Row(
                  children: [
                    const Icon(Icons.route, size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        order.route!.routeName,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: AppTheme.spacingXS),
              const Divider(height: 1),
              const SizedBox(height: AppTheme.spacingXS),

              // Bottom row: date + amount + track hint
              Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 12, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    fmt.format(order.orderDate.toLocal()),
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  if (order.totalAmount > 0)
                    Text(
                      NumberFormat.currency(
                              locale: 'vi_VN', symbol: '₫', decimalDigits: 0)
                          .format(order.totalAmount),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  const SizedBox(width: AppTheme.spacingS),
                  Icon(
                    hasTrip ? Icons.location_on : Icons.chevron_right,
                    color: hasTrip
                        ? Colors.blue
                        : AppTheme.primaryColor,
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Order detail page
// ─────────────────────────────────────────────────────────────────────────────
class _OrderDetailPage extends StatefulWidget {
  final ApiClient api;
  final app_models.Order order;

  const _OrderDetailPage({required this.api, required this.order});

  @override
  State<_OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<_OrderDetailPage> {
  // Location tracking
  app_models.StaffLocationDto? _staffLocation;
  bool _isLoadingLocation = false;
  Timer? _locationTimer;
  final MapController _mapController = MapController();
  bool _isFullscreen = false;
  bool _followStaff = false; // user bật/tắt chế độ bám theo xe

  // Tuyến đường tham khảo
  List<LatLng> _refRoutePoints = [];
  LatLng? _refOriginLatLng;
  LatLng? _refDestLatLng;

  @override
  void initState() {
    super.initState();
    if (_hasTrip) {
      _fetchLocation();
      _locationTimer =
          Timer.periodic(const Duration(seconds: 5), (_) => _fetchLocation());
    }
    // Tải tuyến đường tham khảo nếu có thông tin route
    final route = widget.order.route ?? widget.order.trip?.route;
    if (route != null) {
      _loadReferenceRoute(route.origin, route.destination);
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  bool get _hasTrip =>
      widget.order.tripID != null && widget.order.tripID!.isNotEmpty;

  Future<void> _loadReferenceRoute(String origin, String dest) async {
    final result = await RouteService.fetchReferenceRoute(origin, dest);
    if (!mounted) return;
    setState(() {
      _refRoutePoints = result.points;
      _refOriginLatLng = result.origin;
      _refDestLatLng = result.destination;
    });
    // Fit bản đồ nếu chưa có vị trí staff
    if (result.hasRoute && _staffLocation == null &&
        result.origin != null && result.destination != null) {
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

  Future<void> _fetchLocation() async {
    if (!_hasTrip) return;
    setState(() => _isLoadingLocation = _staffLocation == null);
    try {
      final locations = await widget.api.getActiveLocations();
      final match = locations.where(
        (l) => l.tripID == widget.order.tripID,
      );
      if (match.isNotEmpty) {
        final loc = match.first;
        final isFirst = _staffLocation == null;
        setState(() {
          _staffLocation = loc;
          _isLoadingLocation = false;
        });
        // Pan đến vị trí lần đầu tiên hoặc khi user bật _followStaff
        if ((isFirst || _followStaff) && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _mapController.move(
                LatLng(loc.latitude, loc.longitude),
                _mapController.camera.zoom,
              );
            }
          });
        }
      } else {
        setState(() => _isLoadingLocation = false);
      }
    } catch (e) {
      setState(() => _isLoadingLocation = false);
      ErrorHandler.logError(e, null, 'OrderTracking.fetchLocation');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Color _statusColor(String s) {
    switch (s) {
      case 'Đang vận chuyển':
        return Colors.blue;
      case 'Hoàn thành':
        return Colors.green;
      case 'Hủy':
        return Colors.red;
      case 'Chờ xử lý':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final statusColor = _statusColor(o.status);

    return Stack(
      children: [
        Scaffold(
      backgroundColor: AppTheme.surfaceAlt,
      appBar: AppBar(
        title: Text(
          'Đơn #${o.orderID.length > 8 ? o.orderID.substring(0, 8).toUpperCase() : o.orderID.toUpperCase()}',
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          // Status badge in appbar
          Padding(
            padding: const EdgeInsets.only(right: AppTheme.spacingM),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: statusColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  o.status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        children: [
          // ── Live map (if trip assigned & location available) ───────────────
          if (_hasTrip) _buildMapSection(),

          const SizedBox(height: AppTheme.spacingM),

          // ── Order info ────────────────────────────────────────────────────
          _buildSection(
            icon: Icons.receipt_long,
            title: 'Thông tin đơn hàng',
            color: AppTheme.primaryColor,
            children: [
              _infoRow('Mã đơn', o.orderID),
              _infoRow('Loại đơn', o.orderType),
              _infoRow(
                'Ngày đặt',
                DateFormat('dd/MM/yyyy HH:mm').format(o.orderDate.toLocal()),
              ),
              _infoRow(
                'Giao dự kiến',
                DateFormat('dd/MM/yyyy')
                    .format(o.expectedDeliveryDate.toLocal()),
              ),
              _infoRow(
                  'Tổng trọng lượng', '${o.totalWeight.toStringAsFixed(2)} kg'),
              if (o.note != null && o.note!.isNotEmpty)
                _infoRow('Ghi chú', o.note!),
            ],
          ),

          const SizedBox(height: AppTheme.spacingM),

          // ── Route + Trip ──────────────────────────────────────────────────
          if (o.route != null || o.trip != null)
            _buildSection(
              icon: Icons.route,
              title: 'Tuyến / Chuyến đi',
              color: Colors.teal,
              children: [
                if (o.route != null) ...[
                  _infoRow('Tuyến', o.route!.routeName),
                  _infoRow(
                    'Lộ trình',
                    '${o.route!.origin}  →  ${o.route!.destination}',
                  ),
                  _infoRow('Phương tiện', o.route!.transportType),
                ],
                if (o.trip != null) ...[
                  _infoRow(
                    'Chuyến đi',
                    o.trip!.tripID.substring(0, 8).toUpperCase(),
                  ),
                  _infoRow('Trạng thái chuyến', o.trip!.status),
                  if (o.trip!.departureTime != null)
                    _infoRow(
                      'Khởi hành',
                      DateFormat('dd/MM HH:mm')
                          .format(o.trip!.departureTime!.toLocal()),
                    ),
                  if (o.trip!.vehicle != null)
                    _infoRow('Xe', o.trip!.vehicle!.vehicleName),
                  if (o.trip!.driver != null)
                    _infoRow('Tài xế', o.trip!.driver!.name),
                ],
              ],
            ),

          if (o.route != null || o.trip != null)
            const SizedBox(height: AppTheme.spacingM),

          // ── Sender ────────────────────────────────────────────────────────
          if (o.sender != null)
            _buildSection(
              icon: Icons.person_outline,
              title: 'Người gửi',
              color: Colors.green.shade700,
              children: [
                _infoRow('Tên', o.sender!.name),
                _infoRow('SĐT', o.sender!.phone),
                if (o.sender!.address != null && o.sender!.address!.isNotEmpty)
                  _infoRow('Địa chỉ', o.sender!.address!),
                if (o.sender!.district != null &&
                    o.sender!.district!.isNotEmpty)
                  _infoRow('Quận/Huyện', o.sender!.district!),
                if (o.sender!.branch != null)
                  _infoRow('Chi nhánh', o.sender!.branch!.branchName),
                _infoRow(
                  'Lấy hàng tận nơi',
                  o.sender!.pickupRequired ? 'Có' : 'Không',
                ),
              ],
            ),

          if (o.sender != null) const SizedBox(height: AppTheme.spacingM),

          // ── Receiver ──────────────────────────────────────────────────────
          if (o.receiver != null)
            _buildSection(
              icon: Icons.person_pin_outlined,
              title: 'Người nhận',
              color: Colors.red.shade700,
              children: [
                _infoRow('Tên', o.receiver!.name),
                _infoRow('SĐT', o.receiver!.phone),
                if (o.receiver!.address != null &&
                    o.receiver!.address!.isNotEmpty)
                  _infoRow('Địa chỉ', o.receiver!.address!),
                if (o.receiver!.district != null &&
                    o.receiver!.district!.isNotEmpty)
                  _infoRow('Quận/Huyện', o.receiver!.district!),
                if (o.receiver!.branch != null)
                  _infoRow('Chi nhánh', o.receiver!.branch!.branchName),
                _infoRow(
                  'Giao tận nơi',
                  o.receiver!.deliveryRequired ? 'Có' : 'Không',
                ),
              ],
            ),

          if (o.receiver != null) const SizedBox(height: AppTheme.spacingM),

          // ── Order items ───────────────────────────────────────────────────
          if (o.orderItems != null && o.orderItems!.isNotEmpty)
            _buildItemsSection(o.orderItems!),

          if (o.orderItems != null && o.orderItems!.isNotEmpty)
            const SizedBox(height: AppTheme.spacingM),

          // ── Payment ───────────────────────────────────────────────────────
          if (o.payment != null) _buildPaymentSection(o.payment!),

          const SizedBox(height: AppTheme.spacingL),
        ],
      ),
        ),
        if (_isFullscreen)
          Positioned.fill(child: _buildFullscreenMap()),
      ],
    );
  }

  // ── Map section ────────────────────────────────────────────────────────────

  void _jumpToStaff() {
    final loc = _staffLocation;
    if (loc == null) return;
    _mapController.move(LatLng(loc.latitude, loc.longitude), 15);
  }

  Widget _buildFollowButton() {
    return FloatingActionButton.small(
      heroTag: 'follow_btn',
      onPressed: () {
        setState(() => _followStaff = !_followStaff);
        if (_followStaff) _jumpToStaff();
      },
      backgroundColor: _followStaff ? AppTheme.primaryColor : Colors.white,
      foregroundColor: _followStaff ? Colors.white : Colors.grey.shade700,
      tooltip: _followStaff ? 'Tắt bám theo xe' : 'Bám theo xe',
      child: Icon(_followStaff ? Icons.gps_fixed : Icons.gps_not_fixed),
    );
  }

  /// Bản đồ chung — dùng cả trong chế độ thường và fullscreen
  Widget _buildMapWidget({required bool fullscreen}) {
    final loc = _staffLocation;
    final center = loc != null
        ? LatLng(loc.latitude, loc.longitude)
        : (_refOriginLatLng ?? const LatLng(10.7769, 106.7009));

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 13.0,
        minZoom: 5,
        maxZoom: 18,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.giao_nhan_hang',
          maxZoom: 18,
        ),
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
        if (loc != null)
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(loc.latitude, loc.longitude),
                width: 56,
                height: 56,
                child: _StaffMarker(heading: loc.heading, speed: loc.speedKmh),
              ),
            ],
          ),
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
                    tooltip: widget.order.route?.origin ??
                        widget.order.trip?.route?.origin ??
                        'Xuất phát',
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
                    tooltip: widget.order.route?.destination ??
                        widget.order.trip?.route?.destination ??
                        'Điểm đến',
                  ),
                ),
            ],
          ),
        // Overlay: chưa có vị trí
        if (loc == null && !_isLoadingLocation && !fullscreen)
          const ColoredBox(
            color: Color(0x44000000),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_off, size: 40, color: Colors.white70),
                  SizedBox(height: 8),
                  Text('Staff chưa phát vị trí',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFullscreenMap() {
    return Material(
      color: Colors.black,
      child: Stack(
        children: [
          _buildMapWidget(fullscreen: true),

          // Overlay: chưa có vị trí
          if (_staffLocation == null && !_isLoadingLocation)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_off, size: 48, color: Colors.white70),
                  SizedBox(height: 8),
                  Text('Staff chưa phát vị trí',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),

          // Loading indicator
          if (_isLoadingLocation)
            const Positioned(
              top: 60,
              right: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),

          // Nút thoát fullscreen — góc trên trái
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: FloatingActionButton.small(
                  heroTag: 'fs_close',
                  onPressed: () => setState(() => _isFullscreen = false),
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                  tooltip: 'Thu nhỏ',
                  child: const Icon(Icons.fullscreen_exit),
                ),
              ),
            ),
          ),

          // Nút bám theo xe
          Positioned(
            right: 12,
            bottom: 72,
            child: SafeArea(child: _buildFollowButton()),
          ),

          // Nút về vị trí xe
          if (_staffLocation != null)
            Positioned(
              right: 12,
              bottom: 12,
              child: SafeArea(
                child: FloatingActionButton.small(
                  heroTag: 'fs_locate',
                  onPressed: _jumpToStaff,
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primaryColor,
                  tooltip: 'Về vị trí xe',
                  child: const Icon(Icons.my_location),
                ),
              ),
            ),

          // Info bar dưới cùng
          if (_staffLocation != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: Container(
                  color: Colors.black54,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: _buildLocationInfoRow(
                      _staffLocation!, textColor: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationInfoRow(
    app_models.StaffLocationDto loc, {
    required Color textColor,
  }) {
    return Row(
      children: [
        Icon(Icons.gps_fixed, size: 13, color: textColor),
        const SizedBox(width: 4),
        Text(
          '${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}',
          style: TextStyle(fontSize: 11, color: textColor),
        ),
        const Spacer(),
        if (loc.speedKmh != null && loc.speedKmh! > 0) ...[          Icon(Icons.speed, size: 13, color: textColor),
          const SizedBox(width: 2),
          Text(
            '${loc.speedKmh!.toStringAsFixed(0)} km/h',
            style: TextStyle(fontSize: 11, color: textColor),
          ),
          const SizedBox(width: AppTheme.spacingS),
        ],
        Text(
          DateFormat('HH:mm:ss').format(loc.timestamp.toLocal()),
          style: TextStyle(fontSize: 11, color: textColor),
        ),
      ],
    );
  }

  Widget _buildMapSection() {
    // ── Normal card mode ─────────────────────────────────────────────────────
    final trip = widget.order.trip;
    final route = widget.order.route;
    final loc = _staffLocation;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            color: Colors.blue.shade700,
            padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM, vertical: AppTheme.spacingS),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.white, size: 18),
                const SizedBox(width: AppTheme.spacingXS),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Theo dõi vị trí',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (loc != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    Colors.greenAccent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.circle,
                                      size: 6, color: Colors.greenAccent),
                                  SizedBox(width: 3),
                                  Text(
                                    'LIVE',
                                    style: TextStyle(
                                      color: Colors.greenAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (trip != null || route != null)
                        Text(
                          route != null
                              ? '${route.origin} → ${route.destination}'
                              : 'Chuyến ${widget.order.tripID!.substring(0, 8).toUpperCase()}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11),
                        ),
                    ],
                  ),
                ),
                // Nút fullscreen
                IconButton(
                  icon: const Icon(Icons.fullscreen,
                      color: Colors.white, size: 22),
                  onPressed: () => setState(() => _isFullscreen = true),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Toàn màn hình',
                ),
                const SizedBox(width: 8),
                if (_isLoadingLocation)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh,
                        color: Colors.white70, size: 20),
                    onPressed: _fetchLocation,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),

          // Map
          SizedBox(
            height: 280,
            child: Stack(
              children: [
                _buildMapWidget(fullscreen: false),
                // Nút bám theo xe
                Positioned(
                  right: AppTheme.spacingS,
                  bottom: 52,
                  child: _buildFollowButton(),
                ),
                // Nút về vị trí xe
                if (loc != null)
                  Positioned(
                    right: AppTheme.spacingS,
                    bottom: AppTheme.spacingS,
                    child: FloatingActionButton.small(
                      heroTag: 'detail_locate',
                      onPressed: _jumpToStaff,
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primaryColor,
                      tooltip: 'Về vị trí xe',
                      child: const Icon(Icons.my_location),
                    ),
                  ),
              ],
            ),
          ),

          // Location info strip
          if (loc != null)
            Container(
              color: Colors.blue.shade50,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingM, vertical: AppTheme.spacingXS),
              child: _buildLocationInfoRow(loc,
                  textColor: Colors.blue.shade700),
            ),

          // Staff info strip
          if (loc != null)
            Container(
              color: Colors.blue.shade50,
              padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacingM, 0, AppTheme.spacingM, AppTheme.spacingS),
              child: Row(
                children: [
                  Icon(Icons.person, size: 13, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    loc.staffName.isNotEmpty ? loc.staffName : 'Staff',
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Section builder ────────────────────────────────────────────────────────
  Widget _buildSection({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM, vertical: AppTheme.spacingS),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radiusMedium)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: AppTheme.spacingXS),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingXS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection(List<app_models.OrderItem> items) {
    final currencyFmt = NumberFormat.currency(
        locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM, vertical: AppTheme.spacingS),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radiusMedium)),
            ),
            child: Row(
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 16, color: Colors.orange.shade700),
                const SizedBox(width: AppTheme.spacingXS),
                Text(
                  'Danh sách hàng (${items.length})',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
          ...items.map(
            (item) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingM,
                      vertical: AppTheme.spacingS),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.itemName,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.quantity} ${item.unit}  ·  ${item.weight} kg',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        currencyFmt.format(item.amount),
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor),
                      ),
                    ],
                  ),
                ),
                if (item != items.last)
                  const Divider(height: 1, indent: AppTheme.spacingM),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection(app_models.Payment payment) {
    final fmt = NumberFormat.currency(
        locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM, vertical: AppTheme.spacingS),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radiusMedium)),
            ),
            child: Row(
              children: [
                Icon(Icons.payments_outlined,
                    size: 16, color: Colors.green.shade700),
                const SizedBox(width: AppTheme.spacingXS),
                Text(
                  'Thanh toán',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              children: [
                _infoRow('Phương thức', payment.paymentMethod),
                _infoRow(
                    'Phí vận chuyển', fmt.format(payment.shippingFee)),
                if (payment.codAmount > 0)
                  _infoRow('Thu hộ (COD)', fmt.format(payment.codAmount)),
                if (payment.codFee > 0)
                  _infoRow('Phí COD', fmt.format(payment.codFee)),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tổng thanh toán',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(
                      fmt.format(payment.totalPayment),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Route pin marker (điểm xuất phát / điểm đến)
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

// ─────────────────────────────────────────────────────────────────────────────
// Staff marker widget on the map
// ─────────────────────────────────────────────────────────────────────────────
class _StaffMarker extends StatelessWidget {
  final double? heading;
  final double? speed;

  const _StaffMarker({this.heading, this.speed});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulse ring
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.withValues(alpha: 0.15),
          ),
        ),
        // Inner dot
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: Colors.blue.shade600,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
              ),
            ],
          ),
          child: const Icon(Icons.local_shipping,
              color: Colors.white, size: 14),
        ),
      ],
    );
  }
}
