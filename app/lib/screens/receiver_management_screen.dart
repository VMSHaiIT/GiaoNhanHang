import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../api_client.dart';
import '../models.dart';
import '../ui/design_system.dart';
import '../utils/error_handler.dart';

class ReceiverManagementScreen extends StatefulWidget {
  final ApiClient api;

  const ReceiverManagementScreen({super.key, required this.api});

  @override
  State<ReceiverManagementScreen> createState() =>
      _ReceiverManagementScreenState();
}

class _ReceiverManagementScreenState extends State<ReceiverManagementScreen> {
  List<Receiver> _receivers = [];
  List<Receiver> _filteredReceivers = [];
  List<Branch> _branches = [];
  List<Staff> _staff = [];
  final _searchController = TextEditingController();
  bool _isLoading = false;

  static const List<String> _districtOptions = [
    'Quận 1',
    'Quận 2',
    'Quận 3',
    'Quận 7',
    'Tân Phú',
    'Bình Thạnh',
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
        _filteredReceivers = List.from(_receivers);
      } else {
        _filteredReceivers = _receivers
            .where((r) =>
                r.phone.toLowerCase().contains(q) ||
                (r.name.toLowerCase().contains(q)))
            .toList();
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final receivers = await widget.api.getReceivers();
      final branches = await widget.api.getBranches();
      final staff = await widget.api.getStaff();
      setState(() {
        _receivers = receivers;
        _filteredReceivers = List.from(receivers);
        _branches = branches;
        _staff = staff;
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

  void _openForm({Receiver? receiver}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReceiverFormSheet(
        api: widget.api,
        receiver: receiver,
        branches: _branches,
        staff: _staff,
        districtOptions: _districtOptions,
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

  void _confirmDelete(Receiver receiver) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
            'Bạn có chắc muốn xóa khách nhận "${receiver.name}" (${receiver.phone})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await widget.api.deleteReceiver(receiver.receiverID);
                if (mounted) {
                  AppWidgets.showFlushbar(context, 'Đã xóa khách nhận.',
                      type: MessageType.success);
                  _loadData();
                }
              } catch (e, st) {
                if (mounted) {
                  ErrorHandler.show(context, e,
                      stackTrace: st,
                      shortMessage:
                          'Xóa khách nhận thất bại. Vui lòng thử lại.');
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
      body: _isLoading && _receivers.isEmpty
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
                _filteredReceivers.isEmpty
                    ? SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_pin_circle_outlined,
                                  size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: AppTheme.spacingM),
                              Text(
                                _receivers.isEmpty
                                    ? 'Chưa có khách nhận nào'
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
                              final r = _filteredReceivers[index];
                              return _ReceiverCard(
                                receiver: r,
                                onEdit: () => _openForm(receiver: r),
                                onDelete: () => _confirmDelete(r),
                              );
                            },
                            childCount: _filteredReceivers.length,
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

class _ReceiverCard extends StatelessWidget {
  final Receiver receiver;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ReceiverCard({
    required this.receiver,
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
                  child: Icon(Icons.person_pin, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        receiver.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        receiver.phone,
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
            if (receiver.address != null && receiver.address!.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacingXS),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      receiver.address!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppTheme.spacingXS),
            Wrap(
              spacing: AppTheme.spacingS,
              runSpacing: 4,
              children: [
                if (receiver.branch != null)
                  Chip(
                    label: Text(receiver.branch!.branchName,
                        style: const TextStyle(fontSize: 12)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                if (receiver.district != null)
                  Chip(
                    label: Text(receiver.district!,
                        style: const TextStyle(fontSize: 12)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                if (receiver.deliveryRequired)
                  Chip(
                    avatar: Icon(Icons.local_shipping,
                        size: 16, color: AppTheme.primaryColor),
                    label: const Text('Giao tận nơi',
                        style: TextStyle(fontSize: 12)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiverFormSheet extends StatefulWidget {
  final ApiClient api;
  final Receiver? receiver;
  final List<Branch> branches;
  final List<Staff> staff;
  final List<String> districtOptions;
  final void Function(String? successMessage) onSaved;
  final void Function(String message) onError;

  const _ReceiverFormSheet({
    required this.api,
    this.receiver,
    required this.branches,
    required this.staff,
    required this.districtOptions,
    required this.onSaved,
    required this.onError,
  });

  @override
  State<_ReceiverFormSheet> createState() => _ReceiverFormSheetState();
}

class _ReceiverFormSheetState extends State<_ReceiverFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController;
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  String? _branchId;
  String? _district;
  bool _deliveryRequired = false;
  String? _deliveryStaffId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.receiver;
    _phoneController = TextEditingController(text: r?.phone ?? '');
    _nameController = TextEditingController(text: r?.name ?? '');
    _addressController = TextEditingController(text: r?.address ?? '');
    _branchId = r?.branchID;
    _district = r?.district;
    _deliveryRequired = r?.deliveryRequired ?? false;
    _deliveryStaffId = r?.deliveryStaffID;
    if (_branchId == null && widget.branches.isNotEmpty) {
      _branchId = widget.branches.first.branchID;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final id = widget.receiver?.receiverID ?? const Uuid().v4();
      final receiver = Receiver(
        receiverID: id,
        phone: _phoneController.text.trim(),
        name: _nameController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        branchID: _branchId,
        district: _district,
        deliveryRequired: _deliveryRequired,
        deliveryStaffID: _deliveryStaffId,
      );
      if (widget.receiver != null) {
        await widget.api.updateReceiver(id, receiver);
        widget.onSaved('Đã cập nhật khách nhận.');
      } else {
        await widget.api.createReceiver(receiver);
        widget.onSaved('Đã thêm khách nhận.');
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
    final isEdit = widget.receiver != null;
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
                isEdit ? 'Sửa khách nhận' : 'Thêm khách nhận',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppTheme.spacingM),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại *',
                  hintText: 'Nhập SĐT',
                  prefixIcon: Icon(Icons.phone),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                        Radius.circular(AppTheme.radiusMedium)),
                  ),
                ),
                readOnly: isEdit,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Vui lòng nhập SĐT';
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingS),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Họ tên *',
                  hintText: 'Nhập họ tên',
                  prefixIcon: Icon(Icons.person),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                        Radius.circular(AppTheme.radiusMedium)),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty)
                    return 'Vui lòng nhập họ tên';
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingS),
              TextFormField(
                controller: _addressController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Địa chỉ',
                  hintText: 'Nhập địa chỉ',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                        Radius.circular(AppTheme.radiusMedium)),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingS),
              DropdownButtonFormField<String>(
                initialValue: _branchId,
                decoration: const InputDecoration(
                  labelText: 'Chi nhánh',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                        Radius.circular(AppTheme.radiusMedium)),
                  ),
                ),
                items: widget.branches
                    .map((b) => DropdownMenuItem(
                          value: b.branchID,
                          child: Text(b.branchName),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _branchId = v),
              ),
              const SizedBox(height: AppTheme.spacingS),
              DropdownButtonFormField<String>(
                initialValue: _district,
                decoration: const InputDecoration(
                  labelText: 'Quận / Huyện',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(
                        Radius.circular(AppTheme.radiusMedium)),
                  ),
                ),
                items: widget.districtOptions
                    .map((d) => DropdownMenuItem(
                          value: d,
                          child: Text(d),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _district = v),
              ),
              const SizedBox(height: AppTheme.spacingS),
              Row(
                children: [
                  Checkbox(
                    value: _deliveryRequired,
                    onChanged: (v) =>
                        setState(() => _deliveryRequired = v ?? false),
                    activeColor: AppTheme.primaryColor,
                  ),
                  const Text('Giao tận nơi'),
                  const SizedBox(width: AppTheme.spacingM),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _deliveryStaffId,
                      decoration: const InputDecoration(
                        hintText: 'Chọn NV giao',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(
                              Radius.circular(AppTheme.radiusMedium)),
                        ),
                      ),
                      items: widget.staff
                          .map((s) => DropdownMenuItem(
                                value: s.staffID,
                                child: Text(s.name),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _deliveryStaffId = v),
                    ),
                  ),
                ],
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
