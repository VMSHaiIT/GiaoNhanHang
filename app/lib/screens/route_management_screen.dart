import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../api_client.dart';
import '../models.dart' as app_models;
import '../ui/design_system.dart';
import '../utils/error_handler.dart';

class RouteManagementScreen extends StatefulWidget {
  final ApiClient api;

  const RouteManagementScreen({super.key, required this.api});

  @override
  State<RouteManagementScreen> createState() => _RouteManagementScreenState();
}

class _RouteManagementScreenState extends State<RouteManagementScreen> {
  List<app_models.Route> _routes = [];
  List<app_models.Route> _filteredRoutes = [];
  final _searchController = TextEditingController();
  bool _isLoading = false;

  static const List<String> _transportTypeOptions = [
    'Xe tải',
    'Xe máy',
    'Container',
    'Máy bay',
    'Tàu',
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
        _filteredRoutes = List.from(_routes);
      } else {
        _filteredRoutes = _routes
            .where((r) =>
                r.routeName.toLowerCase().contains(q) ||
                r.origin.toLowerCase().contains(q) ||
                r.destination.toLowerCase().contains(q) ||
                r.transportType.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final routes = await widget.api.getRoutes();
      setState(() {
        _routes = routes;
        _filteredRoutes = List.from(routes);
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

  void _openForm({app_models.Route? route}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RouteFormSheet(
        api: widget.api,
        route: route,
        transportTypeOptions: _transportTypeOptions,
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

  void _confirmDelete(app_models.Route route) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
            'Bạn có chắc muốn xóa tuyến "${route.routeName}" (${route.origin} → ${route.destination})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await widget.api.deleteRoute(route.routeID);
                if (mounted) {
                  AppWidgets.showFlushbar(context, 'Đã xóa tuyến.',
                      type: MessageType.success);
                  _loadData();
                }
              } catch (e, st) {
                if (mounted) {
                  ErrorHandler.show(context, e,
                      stackTrace: st,
                      shortMessage: 'Xóa tuyến thất bại. Vui lòng thử lại.');
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
      body: _isLoading && _routes.isEmpty
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
                            hintText:
                                'Tìm theo tên tuyến, điểm đi, điểm đến...',
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
                _filteredRoutes.isEmpty
                    ? SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.route_outlined,
                                  size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: AppTheme.spacingM),
                              Text(
                                _routes.isEmpty
                                    ? 'Chưa có tuyến nào'
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
                              final r = _filteredRoutes[index];
                              return _RouteCard(
                                route: r,
                                onEdit: () => _openForm(route: r),
                                onDelete: () => _confirmDelete(r),
                              );
                            },
                            childCount: _filteredRoutes.length,
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

class _RouteCard extends StatelessWidget {
  final app_models.Route route;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RouteCard({
    required this.route,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
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
                  child: Icon(Icons.route, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route.routeName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${route.origin} → ${route.destination}',
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
            Chip(
              label: Text(route.transportType,
                  style: const TextStyle(fontSize: 12)),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteFormSheet extends StatefulWidget {
  final ApiClient api;
  final app_models.Route? route;
  final List<String> transportTypeOptions;
  final void Function(String? successMessage) onSaved;
  final void Function(String message) onError;

  const _RouteFormSheet({
    required this.api,
    this.route,
    required this.transportTypeOptions,
    required this.onSaved,
    required this.onError,
  });

  @override
  State<_RouteFormSheet> createState() => _RouteFormSheetState();
}

class _RouteFormSheetState extends State<_RouteFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _routeNameController;
  late final TextEditingController _originController;
  late final TextEditingController _destinationController;
  String? _transportType;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.route;
    _routeNameController = TextEditingController(text: r?.routeName ?? '');
    _originController = TextEditingController(text: r?.origin ?? '');
    _destinationController = TextEditingController(text: r?.destination ?? '');
    _transportType = r?.transportType;
    if (_transportType == null && widget.transportTypeOptions.isNotEmpty) {
      _transportType = widget.transportTypeOptions.first;
    }
  }

  @override
  void dispose() {
    _routeNameController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final id = widget.route?.routeID ?? const Uuid().v4();
      final route = app_models.Route(
        routeID: id,
        routeName: _routeNameController.text.trim(),
        origin: _originController.text.trim(),
        destination: _destinationController.text.trim(),
        transportType: _transportType ?? widget.transportTypeOptions.first,
      );
      if (widget.route != null) {
        await widget.api.updateRoute(id, route);
        widget.onSaved('Đã cập nhật tuyến.');
      } else {
        await widget.api.createRoute(route);
        widget.onSaved('Đã thêm tuyến.');
      }
    } catch (e, st) {
      ErrorHandler.logError(e, st);
      widget.onError(ErrorHandler.toShortMessage(e));
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.route != null;
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
                isEdit ? 'Sửa tuyến' : 'Thêm tuyến',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
              TextFormField(
                controller: _routeNameController,
                decoration: const InputDecoration(
                  labelText: 'Tên tuyến *',
                  hintText: 'Nhập tên tuyến',
                  prefixIcon: Icon(Icons.route),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                        Radius.circular(AppTheme.radiusMedium)),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty)
                    return 'Vui lòng nhập tên tuyến';
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingS),
              TextFormField(
                controller: _originController,
                decoration: const InputDecoration(
                  labelText: 'Điểm đi *',
                  hintText: 'Nhập điểm đi',
                  prefixIcon: Icon(Icons.trip_origin),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                        Radius.circular(AppTheme.radiusMedium)),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty)
                    return 'Vui lòng nhập điểm đi';
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingS),
              TextFormField(
                controller: _destinationController,
                decoration: const InputDecoration(
                  labelText: 'Điểm đến *',
                  hintText: 'Nhập điểm đến',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                        Radius.circular(AppTheme.radiusMedium)),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty)
                    return 'Vui lòng nhập điểm đến';
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingS),
              DropdownButtonFormField<String>(
                value: _transportType,
                decoration: const InputDecoration(
                  labelText: 'Loại vận chuyển',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                        Radius.circular(AppTheme.radiusMedium)),
                  ),
                ),
                items: widget.transportTypeOptions
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _transportType = v),
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
