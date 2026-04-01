import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_client.dart';
import '../models.dart' as app_models;
import '../ui/design_system.dart';
import '../utils/order_status_labels.dart';

class OrderManagementScreen extends StatefulWidget {
  final ApiClient api;

  const OrderManagementScreen({super.key, required this.api});

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  List<app_models.Order> _orders = [];
  List<app_models.Order> _filteredOrders = [];
  bool _isLoading = false;

  String _searchQuery = '';
  String _selectedStatus = OrderStatusLabels.allStatus;
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _statusFilters = [
    OrderStatusLabels.allStatus,
    'pending',
    'collecting',
    'in_stock',
    'delivering',
    'delivered',
    'cancelled',
    'returned',
  ];

  static const Map<String, Color> _statusColors = {
    'pending': Color(0xFFF59E0B),
    'collecting': Color(0xFF3B82F6),
    'in_stock': Color(0xFF8B5CF6),
    'delivering': Color(0xFF06B6D4),
    'delivered': Color(0xFF10B981),
    'cancelled': Color(0xFFEF4444),
    'returned': Color(0xFFEC4899),
  };

  static const Map<String, IconData> _statusIcons = {
    'pending': Icons.hourglass_empty,
    'collecting': Icons.delivery_dining,
    'in_stock': Icons.warehouse,
    'delivering': Icons.local_shipping,
    'delivered': Icons.check_circle,
    'cancelled': Icons.cancel,
    'returned': Icons.undo,
  };

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final orders = await widget.api.getOrders();
      if (mounted) {
        setState(() {
          _orders = orders;
          _applyFilters();
        });
      }
    } catch (e) {
      if (mounted) {
        AppWidgets.showFlushbar(
          context,
          'Lỗi tải đơn hàng: $e',
          type: MessageType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    final q = _searchQuery.toLowerCase().trim();
    _filteredOrders = _orders.where((order) {
      final matchesSearch = q.isEmpty ||
          order.orderID.toLowerCase().contains(q) ||
          (order.sender?.name.toLowerCase().contains(q) ?? false) ||
          (order.receiver?.name.toLowerCase().contains(q) ?? false) ||
          (order.sender?.phone.contains(q) ?? false) ||
          (order.receiver?.phone.contains(q) ?? false);

      final matchesStatus = _selectedStatus == OrderStatusLabels.allStatus ||
          order.status == _selectedStatus;

      return matchesSearch && matchesStatus;
    }).toList();

    _filteredOrders.sort((a, b) => b.createdDate.compareTo(a.createdDate));
  }

  Color _getStatusColor(String status) =>
      _statusColors[status] ?? const Color(0xFF6B7280);

  IconData _getStatusIcon(String status) =>
      _statusIcons[status] ?? Icons.info_outline;

  Map<String, int> get _statusCounts {
    final counts = <String, int>{};
    for (final order in _orders) {
      counts[order.status] = (counts[order.status] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> _deleteOrder(app_models.Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('Xác nhận xóa'),
          ],
        ),
        content: Text(
          'Bạn có chắc muốn xóa đơn hàng ${order.shortId}?\nHành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await widget.api.deleteOrder(order.orderID);
      if (mounted) {
        AppWidgets.showFlushbar(
          context,
          'Đã xóa đơn hàng thành công',
          type: MessageType.success,
        );
        await _loadOrders();
      }
    } catch (e) {
      if (mounted) {
        AppWidgets.showFlushbar(
          context,
          'Lỗi xóa đơn hàng: $e',
          type: MessageType.error,
        );
      }
    }
  }

  void _showOrderDetail(app_models.Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _OrderDetailSheet(
        order: order,
        statusColors: _statusColors,
        statusIcons: _statusIcons,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceAlt,
      body: RefreshIndicator(
        onRefresh: _loadOrders,
        color: AppTheme.primaryColor,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildSearchAndFilter()),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child:
                      CircularProgressIndicator(color: AppTheme.primaryColor),
                ),
              )
            else if (_filteredOrders.isEmpty)
              SliverFillRemaining(child: _buildEmptyState())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _buildOrderCard(_filteredOrders[i]),
                    childCount: _filteredOrders.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final counts = _statusCounts;
    final pending = counts['pending'] ?? 0;
    final collecting = counts['collecting'] ?? 0;
    final inStock = counts['in_stock'] ?? 0;
    final delivering = counts['delivering'] ?? 0;
    final delivered = counts['delivered'] ?? 0;
    final cancelled = counts['cancelled'] ?? 0;
    final returned = counts['returned'] ?? 0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Quản lý đơn hàng',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Theo dõi và quản lý tất cả đơn hàng',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final isSmall = constraints.maxWidth < 600;
              if (isSmall) {
                return Column(
                  children: [
                    // Row 1: Tổng đơn — full width, centered
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Tổng đơn',
                            _orders.length,
                            Icons.assignment,
                            Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Row 2: Chờ lấy, Đang lấy, Trong kho
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            OrderStatusLabels.labelFor('pending'),
                            pending,
                            Icons.hourglass_empty,
                            const Color(0xFFFBBF24),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatCard(
                            OrderStatusLabels.labelFor('collecting'),
                            collecting,
                            Icons.delivery_dining,
                            const Color(0xFF3B82F6),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatCard(
                            OrderStatusLabels.labelFor('in_stock'),
                            inStock,
                            Icons.warehouse,
                            const Color(0xFF8B5CF6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Row 3: Đang giao, Đã giao, Đã hủy, Hoàn hàng
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            OrderStatusLabels.labelFor('delivering'),
                            delivering,
                            Icons.local_shipping,
                            const Color(0xFF67E8F9),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatCard(
                            OrderStatusLabels.labelFor('delivered'),
                            delivered,
                            Icons.check_circle,
                            const Color(0xFF6EE7B7),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatCard(
                            OrderStatusLabels.labelFor('cancelled'),
                            cancelled,
                            Icons.cancel,
                            const Color(0xFFFCA5A5),
                          ),
                        ),
                        Expanded(
                          child: _buildStatCard(
                            OrderStatusLabels.labelFor('returned'),
                            returned,
                            Icons.undo,
                            const Color(0xFFFCA5A5),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }

              // Large screen: single row
              return Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Tổng đơn',
                      _orders.length,
                      Icons.assignment,
                      Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                      OrderStatusLabels.labelFor('pending'),
                      pending,
                      Icons.hourglass_empty,
                      const Color(0xFFFBBF24),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                      OrderStatusLabels.labelFor('collecting'),
                      collecting,
                      Icons.delivery_dining,
                      const Color(0xFF3B82F6),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                      OrderStatusLabels.labelFor('in_stock'),
                      inStock,
                      Icons.warehouse,
                      const Color(0xFF8B5CF6),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                      OrderStatusLabels.labelFor('delivering'),
                      delivering,
                      Icons.local_shipping,
                      const Color(0xFF67E8F9),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                      OrderStatusLabels.labelFor('delivered'),
                      delivered,
                      Icons.check_circle,
                      const Color(0xFF6EE7B7),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                      OrderStatusLabels.labelFor('cancelled'),
                      cancelled,
                      Icons.cancel,
                      const Color(0xFFFCA5A5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                      OrderStatusLabels.labelFor('returned'),
                      returned,
                      Icons.undo,
                      const Color(0xFFFCA5A5),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label, int count, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 6),
          Text(
            count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (v) {
              setState(() {
                _searchQuery = v;
                _applyFilters();
              });
            },
            decoration: InputDecoration(
              hintText: 'Tìm theo mã đơn, tên khách hàng, SĐT...',
              prefixIcon:
                  const Icon(Icons.search, color: AppTheme.primaryColor),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _applyFilters();
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppTheme.surfaceAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _statusFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final status = _statusFilters[i];
                final isSelected = _selectedStatus == status;
                return FilterChip(
                  label: Text(OrderStatusLabels.labelFor(status)),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      _selectedStatus = status;
                      _applyFilters();
                    });
                  },
                  selectedColor: AppTheme.primaryColor,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  checkmarkColor: Colors.white,
                  backgroundColor: AppTheme.surfaceAlt,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : Colors.grey.shade300,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Hiển thị ${_filteredOrders.length} / ${_orders.length} đơn hàng',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildOrderCard(app_models.Order order) {
    final statusColor = _getStatusColor(order.status);
    final statusIcon = _getStatusIcon(order.status);
    final currencyFmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          onTap: () => _showOrderDetail(order),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            order.shortId,
                            style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          order.orderType,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            OrderStatusLabels.labelFor(order.status),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildPartyInfo(
                        Icons.person_outline,
                        'Người gửi',
                        order.sender?.name ?? 'Chưa có',
                        order.sender?.phone ?? '',
                        const Color(0xFF3B82F6),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    Expanded(
                      child: _buildPartyInfo(
                        Icons.person,
                        'Người nhận',
                        order.receiver?.name ?? 'Chưa có',
                        order.receiver?.phone ?? '',
                        const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 13, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text(
                          dateFmt.format(order.createdDate),
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          currencyFmt.format(order.totalAmount),
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _deleteOrder(order),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.delete_outline,
                                size: 16, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPartyInfo(
    IconData icon,
    String role,
    String name,
    String phone,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role,
                  style: TextStyle(
                      color: color, fontSize: 10, fontWeight: FontWeight.w600),
                ),
                Text(
                  name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                if (phone.isNotEmpty)
                  Text(
                    phone,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ||
                    _selectedStatus != OrderStatusLabels.allStatus
                ? 'Không tìm thấy đơn hàng phù hợp'
                : 'Chưa có đơn hàng nào',
            style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          if (_searchQuery.isEmpty &&
              _selectedStatus == OrderStatusLabels.allStatus)
            const Text(
              'Tạo đơn hàng mới để bắt đầu',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          if (_searchQuery.isNotEmpty ||
              _selectedStatus != OrderStatusLabels.allStatus)
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _selectedStatus = OrderStatusLabels.allStatus;
                  _applyFilters();
                });
              },
              icon: const Icon(Icons.filter_alt_off,
                  color: AppTheme.primaryColor),
              label: const Text(
                'Xóa bộ lọc',
                style: TextStyle(color: AppTheme.primaryColor),
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderDetailSheet extends StatelessWidget {
  final app_models.Order order;
  final Map<String, Color> statusColors;
  final Map<String, IconData> statusIcons;

  const _OrderDetailSheet({
    required this.order,
    required this.statusColors,
    required this.statusIcons,
  });

  Color get _statusColor =>
      statusColors[order.status] ?? const Color(0xFF6B7280);
  IconData get _statusIcon => statusIcons[order.status] ?? Icons.info_outline;

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chi tiết đơn hàng',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      order.shortId,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_statusIcon, size: 14, color: _statusColor),
                          const SizedBox(width: 6),
                          Text(
                            OrderStatusLabels.labelFor(order.status),
                            style: TextStyle(
                                color: _statusColor,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 20),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(
                    'Thông tin người gửi',
                    Icons.send,
                    const Color(0xFF3B82F6),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoCard([
                    _buildInfoRow('Tên', order.sender?.name),
                    _buildInfoRow('SĐT', order.sender?.phone),
                    _buildInfoRow('Địa chỉ', order.sender?.address),
                    _buildInfoRow('Khu vực', order.sender?.district),
                    _buildInfoRow(
                        'Chi nhánh', order.sender?.branch?.branchName),
                    _buildInfoRow(
                        'Lấy hàng tận nơi',
                        (order.sender?.pickupRequired ?? false)
                            ? 'Có'
                            : 'Không'),
                  ]),
                  const SizedBox(height: 16),
                  _buildSectionTitle(
                    'Thông tin người nhận',
                    Icons.inbox,
                    const Color(0xFF10B981),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoCard([
                    _buildInfoRow('Tên', order.receiver?.name),
                    _buildInfoRow('SĐT', order.receiver?.phone),
                    _buildInfoRow('Địa chỉ', order.receiver?.address),
                    _buildInfoRow('Khu vực', order.receiver?.district),
                    _buildInfoRow(
                        'Chi nhánh', order.receiver?.branch?.branchName),
                    _buildInfoRow(
                        'Giao tận nơi',
                        (order.receiver?.deliveryRequired ?? false)
                            ? 'Có'
                            : 'Không'),
                  ]),
                  const SizedBox(height: 16),
                  _buildSectionTitle(
                    'Thông tin đơn hàng',
                    Icons.assignment,
                    AppTheme.primaryColor,
                  ),
                  const SizedBox(height: 8),
                  _buildInfoCard([
                    _buildInfoRow('Loại hàng', order.orderType),
                    _buildInfoRow(
                        'Ngày tạo', dateFmt.format(order.createdDate)),
                    _buildInfoRow(
                        'Ngày đặt hàng', dateFmt.format(order.orderDate)),
                    _buildInfoRow('Dự kiến giao',
                        dateFmt.format(order.expectedDeliveryDate)),
                    _buildInfoRow('Tổng khối lượng', '${order.totalWeight} kg'),
                    _buildInfoRow(
                        'Tổng giá trị', currencyFmt.format(order.totalValue)),
                    _buildInfoRow('Ghi chú', order.note),
                    _buildInfoRow('Người tạo', order.createdBy),
                  ]),
                  const SizedBox(height: 16),
                  if (order.route != null || order.trip != null) ...[
                    _buildSectionTitle(
                      'Vận chuyển',
                      Icons.route,
                      const Color(0xFF8B5CF6),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoCard([
                      if (order.route != null) ...[
                        _buildInfoRow('Tuyến', order.route!.routeName),
                        _buildInfoRow('Điểm đi', order.route!.origin),
                        _buildInfoRow('Điểm đến', order.route!.destination),
                        _buildInfoRow(
                            'Phương tiện', order.route!.transportType),
                      ],
                      if (order.trip != null) ...[
                        _buildInfoRow(
                          'Giờ khởi hành',
                          order.trip!.departureTime != null
                              ? dateFmt.format(order.trip!.departureTime!)
                              : null,
                        ),
                        _buildInfoRow('Trạng thái chuyến', order.trip!.status),
                      ],
                    ]),
                    const SizedBox(height: 16),
                  ],
                  if (order.payment != null) ...[
                    _buildSectionTitle(
                      'Thanh toán',
                      Icons.payment,
                      const Color(0xFFF59E0B),
                    ),
                    const SizedBox(height: 8),
                    _buildPaymentCard(order.payment!, currencyFmt),
                    const SizedBox(height: 16),
                  ],
                  if (order.orderItems != null &&
                      order.orderItems!.isNotEmpty) ...[
                    _buildSectionTitle(
                      'Danh sách hàng hóa (${order.orderItems!.length} kiện)',
                      Icons.inventory_2,
                      const Color(0xFF06B6D4),
                    ),
                    const SizedBox(height: 8),
                    ...order.orderItems!
                        .map((item) => _buildOrderItemCard(item, currencyFmt)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildInfoCard(List<Widget> rows) {
    final nonEmpty = rows.whereType<Padding>().toList();
    if (nonEmpty.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: const Text(
          'Không có thông tin',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Column(children: rows),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(
      app_models.Payment payment, NumberFormat currencyFmt) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        children: [
          _buildPaymentRow('Phương thức', payment.paymentMethod, null),
          const Divider(height: 16),
          _buildPaymentRow(
              'Phí vận chuyển', currencyFmt.format(payment.shippingFee), null),
          _buildPaymentRow('COD', currencyFmt.format(payment.codAmount), null),
          _buildPaymentRow('Phí COD', currencyFmt.format(payment.codFee), null),
          const Divider(height: 16),
          _buildPaymentRow(
            'Tổng thanh toán',
            currencyFmt.format(payment.totalPayment),
            const Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(String label, String value, Color? valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight:
                  valueColor != null ? FontWeight.bold : FontWeight.w500,
              fontSize: valueColor != null ? 15 : 13,
              color: valueColor ?? AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemCard(
      app_models.OrderItem item, NumberFormat currencyFmt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF06B6D4).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.inventory_2,
                size: 18, color: Color(0xFF06B6D4)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.quantity} ${item.unit}  •  ${item.weight} kg  •  ${currencyFmt.format(item.price)}/đơn vị',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currencyFmt.format(item.amount),
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                    fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
