import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../api_client.dart';
import '../models.dart';
import '../ui/design_system.dart';
import '../utils/error_handler.dart';

class StaffManagementScreen extends StatefulWidget {
  final ApiClient api;

  const StaffManagementScreen({super.key, required this.api});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  List<Staff> _staffList = [];
  List<Staff> _filteredStaff = [];
  final _searchController = TextEditingController();
  bool _isLoading = false;

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
        _filteredStaff = List.from(_staffList);
      } else {
        _filteredStaff = _staffList
            .where((s) =>
                s.phone.toLowerCase().contains(q) ||
                s.name.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final list = await widget.api.getStaff();
      setState(() {
        _staffList = list;
        _filteredStaff = List.from(list);
      });
    } catch (e, st) {
      if (mounted) {
        ErrorHandler.show(context, e, stackTrace: st,
            shortMessage: 'Không tải được dữ liệu. Vui lòng thử lại.');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _openForm({Staff? staff}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _StaffFormSheet(
        api: widget.api,
        staff: staff,
        onSaved: (successMessage) {
          Navigator.pop(ctx);
          _loadData();
          if (successMessage != null && mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                AppWidgets.showFlushbar(
                    context, successMessage, type: MessageType.success);
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

  void _confirmDelete(Staff staff) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
            'Bạn có chắc muốn xóa nhân viên "${staff.name}" (${staff.phone})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await widget.api.deleteStaff(staff.staffID);
                if (mounted) {
                  AppWidgets.showFlushbar(
                      context, 'Đã xóa nhân viên.', type: MessageType.success);
                  _loadData();
                }
              } catch (e, st) {
                if (mounted) {
                  ErrorHandler.show(context, e, stackTrace: st,
                      shortMessage: 'Xóa nhân viên thất bại. Vui lòng thử lại.');
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
      body: _isLoading && _staffList.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingM),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Quản lý nhân viên',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingM),
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Tìm theo SĐT hoặc tên...',
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
                _filteredStaff.isEmpty
                    ? SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.badge_outlined,
                                  size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: AppTheme.spacingM),
                              Text(
                                _staffList.isEmpty
                                    ? 'Chưa có nhân viên nào'
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
                              final s = _filteredStaff[index];
                              return _StaffCard(
                                staff: s,
                                onEdit: () => _openForm(staff: s),
                                onDelete: () => _confirmDelete(s),
                              );
                            },
                            childCount: _filteredStaff.length,
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

class _StaffCard extends StatelessWidget {
  final Staff staff;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StaffCard({
    required this.staff,
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
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
              child: Icon(Icons.badge, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: AppTheme.spacingS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    staff.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    staff.phone,
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
      ),
    );
  }
}

class _StaffFormSheet extends StatefulWidget {
  final ApiClient api;
  final Staff? staff;
  final void Function(String? successMessage) onSaved;
  final void Function(String message) onError;

  const _StaffFormSheet({
    required this.api,
    this.staff,
    required this.onSaved,
    required this.onError,
  });

  @override
  State<_StaffFormSheet> createState() => _StaffFormSheetState();
}

class _StaffFormSheetState extends State<_StaffFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.staff;
    _nameController = TextEditingController(text: s?.name ?? '');
    _phoneController = TextEditingController(text: s?.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final id = widget.staff?.staffID ?? const Uuid().v4();
      final staff = Staff(
        staffID: id,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
      );
      if (widget.staff != null) {
        await widget.api.updateStaff(id, staff);
        widget.onSaved('Đã cập nhật nhân viên.');
      } else {
        await widget.api.createStaff(staff);
        widget.onSaved('Đã thêm nhân viên.');
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
    final isEdit = widget.staff != null;
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
                isEdit ? 'Sửa nhân viên' : 'Thêm nhân viên',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Họ tên *',
                  hintText: 'Nhập họ tên',
                  prefixIcon: Icon(Icons.person),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.all(Radius.circular(AppTheme.radiusMedium)),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Vui lòng nhập họ tên';
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingS),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại *',
                  hintText: 'Nhập SĐT',
                  prefixIcon: Icon(Icons.phone),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.all(Radius.circular(AppTheme.radiusMedium)),
                  ),
                ),
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Vui lòng nhập SĐT';
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingXL),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
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
