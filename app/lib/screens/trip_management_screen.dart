import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../api_client.dart';
import '../models.dart' as app_models;
import '../ui/design_system.dart';
import '../utils/error_handler.dart';

class TripManagementScreen extends StatefulWidget {
  final ApiClient api;

  const TripManagementScreen({super.key, required this.api});

  @override
  State<TripManagementScreen> createState() => _TripManagementScreenState();
}

class _TripManagementScreenState extends State<TripManagementScreen> {
  List<app_models.Trip> _trips = [];
  List<app_models.Trip> _filteredTrips = [];
  List<app_models.Route> _routes = [];
  final _searchController = TextEditingController();
  bool _isLoading = false;

  static const List<String> _statusOptions = [
    'Chờ',
    'Đang chạy',
    'Hoàn thành',
    'Hủy',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilter);
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredTrips = List.from(_trips);
      } else {
        _filteredTrips = _trips.where((t) {
          final routeName = t.route?.routeName.toLowerCase() ?? '';
          final status = t.status.toLowerCase();
          return routeName.contains(q) ||
              status.contains(q) ||
              t.tripID.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final trips = await widget.api.getTrips();
      final routes = await widget.api.getRoutes();
      setState(() {
        _trips = trips;
        _filteredTrips = List.from(trips);
        _routes = routes;
      });
    } catch (e, st) {
      if (mounted) {
        ErrorHandler.show(context, e,
            stackTrace: st,
            shortMessage: 'Không tải được dữ liệu. Vui lòng thử lại.');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _openForm({app_models.Trip? trip}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TripFormSheet(
        api: widget.api,
        trip: trip,
        routes: _routes,
        statusOptions: _statusOptions,
        onSaved: (successMessage) {
          Navigator.pop(ctx);
          _loadData();
          if (successMessage != null && mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                AppWidgets.showFlushbar(context, successMessage,
                    type: MessageType.success);
              }
            });
          }
        },
        onError: (msg) {
          if (mounted) {
            AppWidgets.showFlushbar(context, msg, type: MessageType.error);
          }
        },
      ),
    );
  }

  void _confirmDelete(app_models.Trip trip) {
    final routeName = trip.route?.routeName ?? trip.routeID;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa chuyến đi (tuyến: $routeName)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await widget.api.deleteTrip(trip.tripID);
                if (mounted) {
                  AppWidgets.showFlushbar(context, 'Đã xóa chuyến đi.',
                      type: MessageType.success);
                  _loadData();
                }
              } catch (e, st) {
                if (mounted) {
                  ErrorHandler.show(context, e,
                      stackTrace: st,
                      shortMessage:
                          'Xóa chuyến đi thất bại. Vui lòng thử lại.');
                }
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceAlt,
      body: _isLoading && _trips.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: AppTheme.spacingM),
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Tìm theo tuyến, trạng thái...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMedium),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _filteredTrips.isEmpty
                    ? SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.directions_transit_outlined,
                                  size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: AppTheme.spacingM),
                              Text(
                                _trips.isEmpty
                                    ? 'Chưa có chuyến đi nào'
                                    : 'Không tìm thấy kết quả',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingM),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final t = _filteredTrips[index];
                              return _TripCard(
                                trip: t,
                                onEdit: () => _openForm(trip: t),
                                onDelete: () => _confirmDelete(t),
                              );
                            },
                            childCount: _filteredTrips.length,
                          ),
                        ),
                      ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final app_models.Trip trip;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TripCard({
    required this.trip,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final routeName = trip.route?.routeName ?? trip.routeID;
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                  child: Icon(Icons.directions_transit,
                      color: AppTheme.primaryColor),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        routeName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        trip.vehicle!.vehicleName,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  color: AppTheme.primaryColor,
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingXS),
            Wrap(
              spacing: AppTheme.spacingS,
              runSpacing: 4,
              children: [
                Chip(
                  label:
                      Text(trip.status, style: const TextStyle(fontSize: 12)),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                if (trip.driver != null)
                  Chip(
                    label: Text(trip.driver!.name,
                        style: const TextStyle(fontSize: 12)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
            if (trip.departureTime != null) ...[
              const SizedBox(height: AppTheme.spacingXS),
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Khởi hành: ${_formatDateTime(trip.departureTime!)}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _TripFormSheet extends StatefulWidget {
  final ApiClient api;
  final app_models.Trip? trip;
  final List<app_models.Route> routes;
  final List<String> statusOptions;
  final void Function(String? successMessage) onSaved;
  final void Function(String message) onError;

  const _TripFormSheet({
    required this.api,
    this.trip,
    required this.routes,
    required this.statusOptions,
    required this.onSaved,
    required this.onError,
  });

  @override
  State<_TripFormSheet> createState() => _TripFormSheetState();
}

class _TripFormSheetState extends State<_TripFormSheet> {
  final _formKey = GlobalKey<FormState>();
  String? _routeId;
  String? _vehicleId;
  String? _driverId;
  String? _status;
  DateTime? _departureTime;
  DateTime? _arrivalTime;
  List<app_models.Vehicle> _vehicles = [];
  List<app_models.Staff> _staff = [];
  bool _saving = false;
  bool _loadedRefs = false;

  @override
  void initState() {
    super.initState();
    final t = widget.trip;
    _routeId = t?.routeID;
    _vehicleId = t?.vehicleID;
    _driverId = t?.driverID;
    _status = t?.status;
    _departureTime = t?.departureTime;
    _arrivalTime = t?.arrivalTime;
    if (_routeId == null && widget.routes.isNotEmpty) {
      _routeId = widget.routes.first.routeID;
    }
    if (_status == null && widget.statusOptions.isNotEmpty) {
      _status = widget.statusOptions.first;
    }
    _loadVehiclesAndStaff();
  }

  Future<void> _loadVehiclesAndStaff() async {
    try {
      final vehicles = await widget.api.getVehicles();
      final staff = await widget.api.getStaff();
      if (mounted) {
        setState(() {
          _vehicles = vehicles;
          _staff = staff;
          _loadedRefs = true;
          if (_vehicleId == null && _vehicles.isNotEmpty) {
            _vehicleId = _vehicles.first.vehicleID;
          }
          if (_driverId == null && _staff.isNotEmpty) {
            _driverId = _staff.first.staffID;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadedRefs = true);
      }
    }
  }

  Future<void> _pickDepartureTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _departureTime ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _departureTime != null
          ? TimeOfDay.fromDateTime(_departureTime!)
          : TimeOfDay.now(),
    );
    if (time == null || !mounted) return;
    setState(() {
      _departureTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickArrivalTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _arrivalTime ?? _departureTime ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _arrivalTime != null
          ? TimeOfDay.fromDateTime(_arrivalTime!)
          : TimeOfDay.now(),
    );
    if (time == null || !mounted) return;
    setState(() {
      _arrivalTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_routeId == null || _routeId!.isEmpty) {
      widget.onError('Vui lòng chọn tuyến.');
      return;
    }
    if (_status == null || _status!.isEmpty) {
      widget.onError('Vui lòng chọn trạng thái.');
      return;
    }
    setState(() => _saving = true);
    try {
      final id = widget.trip?.tripID ?? const Uuid().v4();
      final trip = app_models.Trip(
        tripID: id,
        routeID: _routeId!,
        vehicleID: _vehicleId,
        driverID: _driverId,
        departureTime: _departureTime,
        arrivalTime: _arrivalTime,
        status: _status!,
      );
      if (widget.trip != null) {
        await widget.api.updateTrip(id, trip);
        widget.onSaved('Đã cập nhật chuyến đi.');
      } else {
        await widget.api.createTrip(trip);
        widget.onSaved('Đã thêm chuyến đi.');
      }
    } catch (e, st) {
      ErrorHandler.logError(e, st);
      widget.onError(ErrorHandler.toShortMessage(e));
    } finally {
      setState(() => _saving = false);
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.trip != null;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLarge)),
      ),
      padding: EdgeInsets.only(
        left: AppTheme.spacingM,
        right: AppTheme.spacingM,
        top: AppTheme.spacingM,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.spacingM,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingL),
              Text(
                isEdit ? 'Sửa chuyến đi' : 'Thêm chuyến đi',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
              DropdownButtonFormField<String>(
                value: _routeId,
                decoration: const InputDecoration(
                  labelText: 'Tuyến *',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                        Radius.circular(AppTheme.radiusMedium)),
                  ),
                ),
                items: widget.routes
                    .map((r) => DropdownMenuItem(
                          value: r.routeID,
                          child: Text(r.routeName),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _routeId = v),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Vui lòng chọn tuyến';
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingS),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'Trạng thái *',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                        Radius.circular(AppTheme.radiusMedium)),
                  ),
                ),
                items: widget.statusOptions
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _status = v),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Vui lòng chọn trạng thái';
                  return null;
                },
              ),
              if (_loadedRefs) ...[
                const SizedBox(height: AppTheme.spacingS),
                DropdownButtonFormField<String?>(
                  value: _vehicleId,
                  decoration: const InputDecoration(
                    labelText: 'Phương tiện',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(
                          Radius.circular(AppTheme.radiusMedium)),
                    ),
                  ),
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('-- Không chọn --'),
                    ),
                    ..._vehicles.map((v) => DropdownMenuItem<String?>(
                          value: v.vehicleID,
                          child: Text(v.vehicleName),
                        )),
                  ],
                  onChanged: (v) => setState(() => _vehicleId = v),
                ),
                const SizedBox(height: AppTheme.spacingS),
                DropdownButtonFormField<String?>(
                  value: _driverId,
                  decoration: const InputDecoration(
                    labelText: 'Tài xế',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(
                          Radius.circular(AppTheme.radiusMedium)),
                    ),
                  ),
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('-- Không chọn --'),
                    ),
                    ..._staff.map((s) => DropdownMenuItem<String?>(
                          value: s.staffID,
                          child: Text(s.name),
                        )),
                  ],
                  onChanged: (v) => setState(() => _driverId = v),
                ),
              ],
              const SizedBox(height: AppTheme.spacingS),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Giờ khởi hành'),
                subtitle: Text(
                  _departureTime != null
                      ? _formatDateTime(_departureTime!)
                      : 'Chọn ngày giờ',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDepartureTime,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Giờ đến'),
                subtitle: Text(
                  _arrivalTime != null
                      ? _formatDateTime(_arrivalTime!)
                      : 'Chọn ngày giờ',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickArrivalTime,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
              ),
              const SizedBox(height: AppTheme.spacingXL),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(isEdit ? 'Cập nhật' : 'Thêm mới'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
