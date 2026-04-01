import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../api_client.dart';
import '../models.dart';
import '../ui/design_system.dart';
import '../utils/error_handler.dart';

class SenderManagementScreen extends StatefulWidget {
  final ApiClient api;

  const SenderManagementScreen({super.key, required this.api});

  @override
  State<SenderManagementScreen> createState() => _SenderManagementScreenState();
}

class _SenderManagementScreenState extends State<SenderManagementScreen> {
  List<Sender> _senders = [];
  List<Sender> _filteredSenders = [];
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
        _filteredSenders = List.from(_senders);
      } else {
        _filteredSenders = _senders
            .where((s) =>
                s.phone.toLowerCase().contains(q) ||
                (s.name.toLowerCase().contains(q)))
            .toList();
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final senders = await widget.api.getSenders();
      final branches = await widget.api.getBranches();
      final staff = await widget.api.getStaff();
      setState(() {
        _senders = senders;
        _filteredSenders = List.from(senders);
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

  void _openForm({Sender? sender}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SenderFormSheet(
        api: widget.api,
        sender: sender,
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

  void _confirmDelete(Sender sender) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
            'Bạn có chắc muốn xóa khách gửi "${sender.name}" (${sender.phone})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await widget.api.deleteSender(sender.senderID);
                if (mounted) {
                  AppWidgets.showFlushbar(context, 'Đã xóa khách gửi.',
                      type: MessageType.success);
                  _loadData();
                }
              } catch (e, st) {
                if (mounted) {
                  ErrorHandler.show(context, e,
                      stackTrace: st,
                      shortMessage:
                          'Xóa khách gửi thất bại. Vui lòng thử lại.');
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
      body: _isLoading && _senders.isEmpty
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
                _filteredSenders.isEmpty
                    ? SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_off_outlined,
                                  size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: AppTheme.spacingM),
                              Text(
                                _senders.isEmpty
                                    ? 'Chưa có khách gửi nào'
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
                              final s = _filteredSenders[index];
                              return _SenderCard(
                                sender: s,
                                onEdit: () => _openForm(sender: s),
                                onDelete: () => _confirmDelete(s),
                              );
                            },
                            childCount: _filteredSenders.length,
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

class _SenderCard extends StatelessWidget {
  final Sender sender;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SenderCard({
    required this.sender,
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
                  child: Icon(Icons.person, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sender.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        sender.phone,
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
            if (sender.address != null && sender.address!.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacingXS),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      sender.address!,
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
                if (sender.branch != null)
                  Chip(
                    label: Text(sender.branch!.branchName,
                        style: const TextStyle(fontSize: 12)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                if (sender.district != null)
                  Chip(
                    label: Text(sender.district!,
                        style: const TextStyle(fontSize: 12)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                if (sender.pickupRequired)
                  Chip(
                    avatar: Icon(Icons.local_shipping,
                        size: 16, color: AppTheme.primaryColor),
                    label: const Text('Nhận tận nơi',
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

class _SenderFormSheet extends StatefulWidget {
  final ApiClient api;
  final Sender? sender;
  final List<Branch> branches;
  final List<Staff> staff;
  final List<String> districtOptions;
  final void Function(String? successMessage) onSaved;
  final void Function(String message) onError;

  const _SenderFormSheet({
    required this.api,
    this.sender,
    required this.branches,
    required this.staff,
    required this.districtOptions,
    required this.onSaved,
    required this.onError,
  });

  @override
  State<_SenderFormSheet> createState() => _SenderFormSheetState();
}

class _SenderFormSheetState extends State<_SenderFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController;
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  String? _branchId;
  String? _district;
  bool _pickupRequired = false;
  String? _pickupStaffId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.sender;
    _phoneController = TextEditingController(text: s?.phone ?? '');
    _nameController = TextEditingController(text: s?.name ?? '');
    _addressController = TextEditingController(text: s?.address ?? '');
    _branchId = s?.branchID;
    _district = s?.district;
    _pickupRequired = s?.pickupRequired ?? false;
    _pickupStaffId = s?.pickupStaffID;
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
      final id = widget.sender?.senderID ?? const Uuid().v4();
      final sender = Sender(
        senderID: id,
        phone: _phoneController.text.trim(),
        name: _nameController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        branchID: _branchId,
        district: _district,
        pickupRequired: _pickupRequired,
        pickupStaffID: _pickupStaffId,
      );
      if (widget.sender != null) {
        await widget.api.updateSender(id, sender);
        widget.onSaved('Đã cập nhật khách gửi.');
      } else {
        await widget.api.createSender(sender);
        widget.onSaved('Đã thêm khách gửi.');
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
    final isEdit = widget.sender != null;
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
                isEdit ? 'Sửa khách gửi' : 'Thêm khách gửi',
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
                    value: _pickupRequired,
                    onChanged: (v) =>
                        setState(() => _pickupRequired = v ?? false),
                    activeColor: AppTheme.primaryColor,
                  ),
                  const Text('Nhận tận nơi'),
                  const SizedBox(width: AppTheme.spacingM),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _pickupStaffId,
                      decoration: const InputDecoration(
                        hintText: 'Chọn NV nhận',
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
                      onChanged: (v) => setState(() => _pickupStaffId = v),
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
