import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../api_client.dart';
import '../models.dart' as app_models;
import '../ui/design_system.dart';
import '../ui/image_picker_helper.dart';
import '../utils/error_handler.dart';

/// Breakpoints for responsive layout (logical pixels).
const double _kBreakpointMobile = 600;
const double _kBreakpointTablet = 900;
const double _kBreakpointDesktop = 1200;
const double _kMaxContentWidth = 1900;

class CreateOrderScreen extends StatefulWidget {
  final ApiClient api;

  const CreateOrderScreen({super.key, required this.api});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();

  // Sender controllers
  final _senderPhoneController = TextEditingController();
  final _senderNameController = TextEditingController();
  final _senderAddressController = TextEditingController();
  String? _selectedBranchId;
  String? _selectedPickupStaffId;
  String? _selectedSenderDistrict;
  bool _pickupRequired = false;

  // Receiver controllers
  final _receiverPhoneController = TextEditingController();
  final _receiverNameController = TextEditingController();
  final _receiverAddressController = TextEditingController();
  String? _selectedReceiverBranchId;
  String? _selectedDeliveryStaffId;
  String? _selectedReceiverDistrict;
  bool _deliveryRequired = false;

  // Order controllers
  String _orderType = 'Hàng thông thường';
  DateTime _orderDate = DateTime.now();
  DateTime _expectedDeliveryDate = DateTime.now();
  final _totalValueController = TextEditingController();
  final _noteController = TextEditingController();

  // Order items
  List<OrderItemInput> _orderItems = [OrderItemInput()];

  // Delivery & Payment
  String? _selectedRouteId;
  String? _selectedTripId;
  String? _selectedPaymentMethod;
  final _codAmountController = TextEditingController(text: '0');
  final _codFeeController = TextEditingController(text: '0');
  double _shippingFee = 0.0;
  double _totalPayment = 0.0;

  // Data lists
  List<app_models.Branch> _branches = [];
  List<app_models.Staff> _staff = [];
  List<app_models.Route> _routes = [];
  List<app_models.Trip> _trips = [];

  bool _isLoading = false;
  String? _branchName;

  // Phone autocomplete
  List<app_models.Sender> _senderSuggestions = [];
  List<app_models.Receiver> _receiverSuggestions = [];
  Timer? _senderSearchDebounce;
  Timer? _receiverSearchDebounce;
  bool _showSenderDropdown = false;
  bool _showReceiverDropdown = false;
  bool _senderSearching = false;
  bool _receiverSearching = false;
  final FocusNode _senderPhoneFocusNode = FocusNode();
  final FocusNode _receiverPhoneFocusNode = FocusNode();

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
    _codAmountController.addListener(_calculateTotalPayment);
    _codFeeController.addListener(_calculateTotalPayment);
    _senderPhoneFocusNode.addListener(_onSenderPhoneFocusChange);
    _receiverPhoneFocusNode.addListener(_onReceiverPhoneFocusChange);
  }

  void _onSenderPhoneFocusChange() {
    if (!_senderPhoneFocusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _showSenderDropdown = false);
      });
    }
  }

  void _onReceiverPhoneFocusChange() {
    if (!_receiverPhoneFocusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _showReceiverDropdown = false);
      });
    }
  }

  @override
  void dispose() {
    _senderSearchDebounce?.cancel();
    _receiverSearchDebounce?.cancel();
    _senderPhoneFocusNode.removeListener(_onSenderPhoneFocusChange);
    _receiverPhoneFocusNode.removeListener(_onReceiverPhoneFocusChange);
    _senderPhoneFocusNode.dispose();
    _receiverPhoneFocusNode.dispose();
    _searchController.dispose();
    _senderPhoneController.dispose();
    _senderNameController.dispose();
    _senderAddressController.dispose();
    _receiverPhoneController.dispose();
    _receiverNameController.dispose();
    _receiverAddressController.dispose();
    _totalValueController.dispose();
    _noteController.dispose();
    _codAmountController.removeListener(_calculateTotalPayment);
    _codFeeController.removeListener(_calculateTotalPayment);
    _codAmountController.dispose();
    _codFeeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final branches = await widget.api.getBranches();
      final staff = await widget.api.getStaff();
      final routes = await widget.api.getRoutes();

      setState(() {
        _branches = branches;
        _staff = staff;
        _routes = routes;
        if (_branches.isNotEmpty) {
          _selectedBranchId = _branches.first.branchID;
          _selectedReceiverBranchId = _branches.first.branchID;
          _branchName = _branches.first.branchName;
        }
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

  void _calculateTotalPayment() {
    final codAmount = double.tryParse(_codAmountController.text) ?? 0.0;
    final codFee = double.tryParse(_codFeeController.text) ?? 0.0;
    setState(() {
      _totalPayment = _shippingFee + codAmount + codFee;
    });
  }

  void _addOrderItem() {
    setState(() {
      _orderItems.add(OrderItemInput());
    });
  }

  void _removeOrderItem(int index) {
    if (_orderItems.length > 1) {
      setState(() {
        _orderItems.removeAt(index);
      });
    }
  }

  void _updateItemAmount(OrderItemInput item) {
    final qty = int.tryParse(item.quantityController.text) ?? 0;
    final price = double.tryParse(item.priceController.text) ?? 0.0;
    item.amountController.text = (qty * price).toStringAsFixed(0);
  }

  Future<void> _loadTripsForRoute(String? routeId) async {
    if (routeId == null) {
      setState(() {
        _trips = [];
        _selectedTripId = null;
      });
      return;
    }

    try {
      final trips = await widget.api.getTrips(routeId: routeId);
      setState(() {
        _trips = trips;
        _selectedTripId = trips.isNotEmpty ? trips.first.tripID : null;
      });
    } catch (e, st) {
      ErrorHandler.show(context, e,
          stackTrace: st,
          shortMessage: 'Không tải được danh sách chuyến. Vui lòng thử lại.');
    }
  }

  void _onSenderPhoneChanged(String value) {
    _senderSearchDebounce?.cancel();
    if (value.trim().length < 3) {
      setState(() {
        _senderSuggestions = [];
        _showSenderDropdown = false;
      });
      return;
    }
    _senderSearchDebounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _senderSearching = true);
      try {
        final list = await widget.api.searchSendersByPhone(value);
        if (mounted) {
          setState(() {
            _senderSuggestions = list;
            _showSenderDropdown = list.isNotEmpty;
            _senderSearching = false;
          });
        }
      } catch (e, st) {
        if (mounted) {
          setState(() {
            _senderSuggestions = [];
            _showSenderDropdown = false;
            _senderSearching = false;
          });
          ErrorHandler.show(context, e,
              stackTrace: st,
              shortMessage: 'Tìm kiếm người gửi thất bại. Vui lòng thử lại.');
        }
      }
    });
  }

  void _onReceiverPhoneChanged(String value) {
    _receiverSearchDebounce?.cancel();
    if (value.trim().length < 3) {
      setState(() {
        _receiverSuggestions = [];
        _showReceiverDropdown = false;
      });
      return;
    }
    _receiverSearchDebounce =
        Timer(const Duration(milliseconds: 300), () async {
      setState(() => _receiverSearching = true);
      try {
        final list = await widget.api.searchReceiversByPhone(value);
        if (mounted) {
          setState(() {
            _receiverSuggestions = list;
            _showReceiverDropdown = list.isNotEmpty;
            _receiverSearching = false;
          });
        }
      } catch (e, st) {
        if (mounted) {
          setState(() {
            _receiverSuggestions = [];
            _showReceiverDropdown = false;
            _receiverSearching = false;
          });
          ErrorHandler.show(context, e,
              stackTrace: st,
              shortMessage: 'Tìm kiếm người nhận thất bại. Vui lòng thử lại.');
        }
      }
    });
  }

  void _selectSender(app_models.Sender sender) {
    _senderPhoneController.text = sender.phone;
    _senderNameController.text = sender.name;
    _senderAddressController.text = sender.address ?? '';
    _selectedSenderDistrict =
        sender.district != null && _districtOptions.contains(sender.district!)
            ? sender.district
            : null;
    if (sender.branchID != null) _selectedBranchId = sender.branchID;
    setState(() {
      _senderSuggestions = [];
      _showSenderDropdown = false;
    });
    _senderPhoneFocusNode.unfocus();
  }

  void _selectReceiver(app_models.Receiver receiver) {
    _receiverPhoneController.text = receiver.phone;
    _receiverNameController.text = receiver.name;
    _receiverAddressController.text = receiver.address ?? '';
    if (receiver.branchID != null)
      _selectedReceiverBranchId = receiver.branchID;
    _selectedReceiverDistrict = receiver.district != null &&
            _districtOptions.contains(receiver.district!)
        ? receiver.district
        : null;
    setState(() {
      _receiverSuggestions = [];
      _showReceiverDropdown = false;
    });
    _receiverPhoneFocusNode.unfocus();
  }

  Future<void> _saveOrder(
      {bool createNew = false,
      bool printOrder = false,
      bool printLabel = false}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final orderId = const Uuid().v4();

      // Create Sender
      app_models.Sender? sender;
      if (_senderPhoneController.text.isNotEmpty &&
          _senderNameController.text.isNotEmpty) {
        sender = app_models.Sender(
          senderID: const Uuid().v4(),
          phone: _senderPhoneController.text,
          name: _senderNameController.text,
          address: _senderAddressController.text.isEmpty
              ? null
              : _senderAddressController.text,
          branchID: _selectedBranchId,
          district: _selectedSenderDistrict,
          pickupRequired: _pickupRequired,
          pickupStaffID: _selectedPickupStaffId,
        );
      }

      // Create Receiver
      app_models.Receiver? receiver;
      if (_receiverPhoneController.text.isNotEmpty &&
          _receiverNameController.text.isNotEmpty) {
        receiver = app_models.Receiver(
          receiverID: const Uuid().v4(),
          phone: _receiverPhoneController.text,
          name: _receiverNameController.text,
          address: _receiverAddressController.text.isEmpty
              ? null
              : _receiverAddressController.text,
          branchID: _selectedReceiverBranchId,
          district: _selectedReceiverDistrict,
          deliveryRequired: _deliveryRequired,
          deliveryStaffID: _selectedDeliveryStaffId,
        );
      }

      // Calculate totals
      double totalWeight = 0.0;
      double totalAmount = 0.0;
      final orderItems = _orderItems.map((item) {
        final weight = double.tryParse(item.weightController.text) ?? 0.0;
        final quantity = int.tryParse(item.quantityController.text) ?? 0;
        final price = double.tryParse(item.priceController.text) ?? 0.0;
        final amount = price * quantity;

        totalWeight += weight * quantity;
        totalAmount += amount;

        return app_models.OrderItem(
          itemID: const Uuid().v4(),
          orderID: orderId,
          itemName: item.nameController.text,
          unit: item.unit,
          weight: weight,
          quantity: quantity,
          price: price,
          amount: amount,
          imageUrl: item.imageUrl,
        );
      }).toList();

      final totalValue = double.tryParse(_totalValueController.text) ?? 0.0;

      // Create Order
      final order = app_models.Order(
        orderID: orderId,
        orderDate: _orderDate,
        expectedDeliveryDate: _expectedDeliveryDate,
        orderType: _orderType,
        totalValue: totalValue,
        note: _noteController.text.isEmpty ? null : _noteController.text,
        totalWeight: totalWeight,
        totalAmount: totalAmount,
        status: 'Mới',
        createdDate: DateTime.now(),
        createdBy: 'shop_owner',
        routeID: _selectedRouteId,
        tripID: _selectedTripId,
      );

      // Create Payment
      final codAmount = double.tryParse(_codAmountController.text) ?? 0.0;
      final codFee = double.tryParse(_codFeeController.text) ?? 0.0;
      final payment = app_models.Payment(
        paymentID: const Uuid().v4(),
        orderID: orderId,
        shippingFee: _shippingFee,
        codAmount: codAmount,
        codFee: codFee,
        totalPayment: _totalPayment,
        paymentMethod: _selectedPaymentMethod ?? '',
      );

      final request = app_models.CreateOrderRequest(
        order: order,
        sender: sender,
        receiver: receiver,
        orderItems: orderItems,
        payment: payment,
      );

      await widget.api.createOrder(request);

      if (mounted) {
        AppWidgets.showFlushbar(context, 'Lưu đơn hàng thành công!',
            type: MessageType.success);

        if (createNew) {
          _resetForm();
        } else if (printOrder || printLabel) {
          // TODO: Implement print functionality
          AppWidgets.showFlushbar(context, 'Chức năng in đang được phát triển',
              type: MessageType.info);
        }
      }
    } catch (e, st) {
      if (mounted) {
        ErrorHandler.show(context, e,
            stackTrace: st,
            shortMessage: 'Lưu đơn hàng thất bại. Vui lòng thử lại.');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    setState(() {
      _senderPhoneController.clear();
      _senderNameController.clear();
      _senderAddressController.clear();
      _receiverPhoneController.clear();
      _receiverNameController.clear();
      _receiverAddressController.clear();
      _senderSuggestions = [];
      _receiverSuggestions = [];
      _showSenderDropdown = false;
      _showReceiverDropdown = false;
      _selectedBranchId =
          _branches.isNotEmpty ? _branches.first.branchID : null;
      _selectedReceiverBranchId =
          _branches.isNotEmpty ? _branches.first.branchID : null;
      _selectedSenderDistrict = null;
      _selectedReceiverDistrict = null;
      _totalValueController.clear();
      _noteController.clear();
      _codAmountController.text = '0';
      _codFeeController.text = '0';
      _orderItems = [OrderItemInput()];
      _pickupRequired = false;
      _deliveryRequired = false;
      _selectedPickupStaffId = null;
      _selectedDeliveryStaffId = null;
      _selectedRouteId = null;
      _selectedTripId = null;
      _selectedPaymentMethod = null;
      _orderDate = DateTime.now();
      _expectedDeliveryDate = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceAlt,
      body: _isLoading && _branches.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final isDesktop = width >= _kBreakpointDesktop;
                final padding = width >= _kBreakpointDesktop
                    ? AppTheme.spacingL
                    : (width >= _kBreakpointMobile
                        ? AppTheme.spacingM
                        : AppTheme.spacingS);

                final formContent = Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(context),
                      SizedBox(
                          height: width >= _kBreakpointMobile
                              ? AppTheme.spacingL
                              : AppTheme.spacingM),

                      // Panels: 3 cols desktop | 2 cols tablet | 1 col mobile
                      _buildPanelsLayout(context, width),
                      SizedBox(
                          height: width >= _kBreakpointMobile
                              ? AppTheme.spacingL
                              : AppTheme.spacingM),

                      _buildOrderItemsSection(context),
                      SizedBox(
                          height: width >= _kBreakpointMobile
                              ? AppTheme.spacingL
                              : AppTheme.spacingM),

                      _buildDeliveryPaymentSection(context),
                      SizedBox(
                          height: width >= _kBreakpointMobile
                              ? AppTheme.spacingL
                              : AppTheme.spacingM),

                      _buildActionButtons(context),
                    ],
                  ),
                );

                final constrainedContent = isDesktop &&
                        width > _kMaxContentWidth
                    ? Center(
                        child: ConstrainedBox(
                          constraints:
                              const BoxConstraints(maxWidth: _kMaxContentWidth),
                          child: formContent,
                        ),
                      )
                    : formContent;

                return SafeArea(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(padding),
                    child: constrainedContent,
                  ),
                );
              },
            ),
    );
  }

  Widget _buildPanelsLayout(BuildContext context, double width) {
    if (width >= _kBreakpointDesktop) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _buildSenderPanel(context)),
            SizedBox(width: AppTheme.spacingM),
            Expanded(child: _buildReceiverPanel(context)),
            SizedBox(width: AppTheme.spacingM),
            Expanded(child: _buildOrderPanel(context)),
          ],
        ),
      );
    }
    if (width >= _kBreakpointTablet) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildSenderPanel(context)),
                SizedBox(width: AppTheme.spacingM),
                Expanded(child: _buildReceiverPanel(context)),
              ],
            ),
          ),
          SizedBox(height: AppTheme.spacingM),
          _buildOrderPanel(context),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSenderPanel(context),
        SizedBox(height: AppTheme.spacingM),
        _buildReceiverPanel(context),
        SizedBox(height: AppTheme.spacingM),
        _buildOrderPanel(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isNarrow = width < _kBreakpointMobile;

    if (isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Nhập tìm kiếm...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _branchName ?? 'TPH',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'tanphu',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                  const SizedBox(width: AppTheme.spacingS),
                  const CircleAvatar(
                    radius: 18,
                    child: Icon(Icons.person, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Nhập tìm kiếm...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spacingM),
        Text(
          _branchName ?? 'TPH',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: AppTheme.spacingS),
        Text(
          'tanphu',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
        ),
        const SizedBox(width: AppTheme.spacingS),
        const CircleAvatar(
          radius: 18,
          child: Icon(Icons.person, size: 20),
        ),
      ],
    );
  }

  Widget _buildSenderPanel(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < _kBreakpointMobile;
    final stackAddressDistrict = width < _kMaxContentWidth;
    return _buildPanel(
      context: context,
      title: 'Thông tin khách gửi',
      icon: Icons.delete_outline,
      onClear: () {
        setState(() {
          _senderPhoneController.clear();
          _senderNameController.clear();
          _senderAddressController.clear();
          _senderSuggestions = [];
          _showSenderDropdown = false;
          _selectedBranchId =
              _branches.isNotEmpty ? _branches.first.branchID : null;
          _selectedPickupStaffId = null;
          _selectedSenderDistrict = null;
          _pickupRequired = false;
        });
      },
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _senderPhoneController,
                  focusNode: _senderPhoneFocusNode,
                  onChanged: _onSenderPhoneChanged,
                  decoration: InputDecoration(
                    hintText: 'Nhập điện thoại',
                    suffixIcon: _senderSearching
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Icon(Icons.arrow_drop_down),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                if (_showSenderDropdown && _senderSuggestions.isNotEmpty)
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _senderSuggestions.length,
                      itemBuilder: (context, index) {
                        final s = _senderSuggestions[index];
                        return InkWell(
                          onTap: () => _selectSender(s),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.phone,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                if (s.name.isNotEmpty)
                                  Text(
                                    s.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingS),
            TextFormField(
              controller: _senderNameController,
              decoration: const InputDecoration(
                hintText: 'Nhập họ tên',
                prefixIcon: Icon(Icons.person),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            DropdownButtonFormField<String>(
              value: _selectedBranchId,
              decoration: const InputDecoration(
                filled: true,
                fillColor: Colors.white,
              ),
              items: _branches
                  .map((b) => DropdownMenuItem(
                        value: b.branchID,
                        child: Text(b.branchName),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _selectedBranchId = value),
            ),
            const SizedBox(height: AppTheme.spacingS),
            isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _pickupRequired,
                            onChanged: (value) => setState(
                                () => _pickupRequired = value ?? false),
                            activeColor: AppTheme.primaryColor,
                          ),
                          const Text('Nhận tận nơi'),
                        ],
                      ),
                      DropdownButtonFormField<String>(
                        value: _selectedPickupStaffId,
                        decoration: const InputDecoration(
                          hintText: 'Chọn NV nhận',
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: _staff
                            .map((s) => DropdownMenuItem(
                                  value: s.staffID,
                                  child: Text(s.name),
                                ))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedPickupStaffId = value),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Checkbox(
                        value: _pickupRequired,
                        onChanged: (value) =>
                            setState(() => _pickupRequired = value ?? false),
                        activeColor: AppTheme.primaryColor,
                      ),
                      const Text('Nhận tận nơi'),
                      const SizedBox(width: AppTheme.spacingM),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedPickupStaffId,
                          decoration: const InputDecoration(
                            hintText: 'Chọn NV nhận',
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: _staff
                              .map((s) => DropdownMenuItem(
                                    value: s.staffID,
                                    child: Text(s.name),
                                  ))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _selectedPickupStaffId = value),
                        ),
                      ),
                    ],
                  ),
            const SizedBox(height: AppTheme.spacingS),
            stackAddressDistrict
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _senderAddressController,
                        decoration: const InputDecoration(
                          hintText: 'Nhập địa chỉ nhận',
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      DropdownButtonFormField<String>(
                        value: _selectedSenderDistrict,
                        decoration: const InputDecoration(
                          hintText: 'Chọn Quận/Huyện',
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: _districtOptions
                            .map((d) => DropdownMenuItem(
                                  value: d,
                                  child: Text(d),
                                ))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedSenderDistrict = value),
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _senderAddressController,
                          decoration: const InputDecoration(
                            hintText: 'Nhập địa chỉ nhận',
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedSenderDistrict,
                          decoration: const InputDecoration(
                            hintText: 'Chọn Quận/Huyện',
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: _districtOptions
                              .map((d) => DropdownMenuItem(
                                    value: d,
                                    child: Text(d),
                                  ))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _selectedSenderDistrict = value),
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiverPanel(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < _kBreakpointMobile;
    final stackAddressDistrict = width < _kMaxContentWidth;
    return _buildPanel(
      context: context,
      title: 'Thông tin khách nhận',
      icon: Icons.delete_outline,
      onClear: () {
        setState(() {
          _receiverPhoneController.clear();
          _receiverNameController.clear();
          _receiverAddressController.clear();
          _receiverSuggestions = [];
          _showReceiverDropdown = false;
          _selectedReceiverBranchId =
              _branches.isNotEmpty ? _branches.first.branchID : null;
          _selectedDeliveryStaffId = null;
          _selectedReceiverDistrict = null;
          _deliveryRequired = false;
        });
      },
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _receiverPhoneController,
                  focusNode: _receiverPhoneFocusNode,
                  onChanged: _onReceiverPhoneChanged,
                  decoration: InputDecoration(
                    hintText: 'Nhập điện thoại',
                    suffixIcon: _receiverSearching
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Icon(Icons.arrow_drop_down),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                if (_showReceiverDropdown && _receiverSuggestions.isNotEmpty)
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _receiverSuggestions.length,
                      itemBuilder: (context, index) {
                        final r = _receiverSuggestions[index];
                        return InkWell(
                          onTap: () => _selectReceiver(r),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.phone,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                if (r.name.isNotEmpty)
                                  Text(
                                    r.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingS),
            TextFormField(
              controller: _receiverNameController,
              decoration: const InputDecoration(
                hintText: 'Nhập họ tên',
                prefixIcon: Icon(Icons.person),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            DropdownButtonFormField<String>(
              value: _selectedReceiverBranchId,
              decoration: const InputDecoration(
                filled: true,
                fillColor: Colors.white,
              ),
              items: _branches
                  .map((b) => DropdownMenuItem(
                        value: b.branchID,
                        child: Text(b.branchName),
                      ))
                  .toList(),
              onChanged: (value) =>
                  setState(() => _selectedReceiverBranchId = value),
            ),
            const SizedBox(height: AppTheme.spacingS),
            isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _deliveryRequired,
                            onChanged: (value) => setState(
                                () => _deliveryRequired = value ?? false),
                            activeColor: AppTheme.primaryColor,
                          ),
                          const Text('Giao tận nơi'),
                        ],
                      ),
                      DropdownButtonFormField<String>(
                        value: _selectedDeliveryStaffId,
                        decoration: const InputDecoration(
                          hintText: 'Chọn NV giao',
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: _staff
                            .map((s) => DropdownMenuItem(
                                  value: s.staffID,
                                  child: Text(s.name),
                                ))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedDeliveryStaffId = value),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Checkbox(
                        value: _deliveryRequired,
                        onChanged: (value) =>
                            setState(() => _deliveryRequired = value ?? false),
                        activeColor: AppTheme.primaryColor,
                      ),
                      const Text('Giao tận nơi'),
                      const SizedBox(width: AppTheme.spacingM),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedDeliveryStaffId,
                          decoration: const InputDecoration(
                            hintText: 'Chọn NV giao',
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: _staff
                              .map((s) => DropdownMenuItem(
                                    value: s.staffID,
                                    child: Text(s.name),
                                  ))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _selectedDeliveryStaffId = value),
                        ),
                      ),
                    ],
                  ),
            const SizedBox(height: AppTheme.spacingS),
            stackAddressDistrict
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _receiverAddressController,
                        decoration: const InputDecoration(
                          hintText: 'Nhập địa chỉ giao',
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingS),
                      DropdownButtonFormField<String>(
                        value: _selectedReceiverDistrict,
                        decoration: const InputDecoration(
                          hintText: 'Chọn Quận/Huyện',
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: _districtOptions
                            .map((d) => DropdownMenuItem(
                                  value: d,
                                  child: Text(d),
                                ))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedReceiverDistrict = value),
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _receiverAddressController,
                          decoration: const InputDecoration(
                            hintText: 'Nhập địa chỉ giao',
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingS),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedReceiverDistrict,
                          decoration: const InputDecoration(
                            hintText: 'Chọn Quận/Huyện',
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: _districtOptions
                              .map((d) => DropdownMenuItem(
                                    value: d,
                                    child: Text(d),
                                  ))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _selectedReceiverDistrict = value),
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderPanel(BuildContext context) {
    return _buildPanel(
      context: context,
      title: 'Thông tin đơn hàng',
      icon: Icons.delete_outline,
      onClear: () {
        setState(() {
          _orderType = 'Hàng thông thường';
          _orderDate = DateTime.now();
          _expectedDeliveryDate = DateTime.now();
          _totalValueController.clear();
          _noteController.clear();
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            value: _orderType,
            decoration: const InputDecoration(
              filled: true,
              fillColor: Colors.white,
            ),
            items: ['Hàng thông thường', 'Hàng đặc biệt']
                .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t),
                    ))
                .toList(),
            onChanged: (value) =>
                setState(() => _orderType = value ?? 'Hàng thông thường'),
          ),
          const SizedBox(height: AppTheme.spacingS),
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _orderDate,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) setState(() => _orderDate = date);
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                filled: true,
                fillColor: Colors.white,
                suffixIcon: Icon(Icons.calendar_today, size: 20),
              ),
              child: Text(
                  'Ngày đơn hàng: ${DateFormat('yyyy-MM-dd').format(_orderDate)}'),
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _expectedDeliveryDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) setState(() => _expectedDeliveryDate = date);
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                filled: true,
                fillColor: Colors.white,
                suffixIcon: Icon(Icons.calendar_today, size: 20),
              ),
              child: Text(
                  'Giao dự kiến: ${DateFormat('yyyy-MM-dd').format(_expectedDeliveryDate)}'),
            ),
          ),
          const SizedBox(height: AppTheme.spacingS),
          TextFormField(
            controller: _totalValueController,
            decoration: const InputDecoration(
              hintText: 'Nhập tổng giá trị hàng gửi',
              prefixText: '\$ ',
              filled: true,
              fillColor: Colors.white,
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppTheme.spacingS),
          TextFormField(
            controller: _noteController,
            decoration: const InputDecoration(
              hintText: 'Ghi chú',
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel({
    required String title,
    required IconData icon,
    required VoidCallback onClear,
    required Widget child,
    BuildContext? context,
  }) {
    final isMobile = context != null &&
        MediaQuery.sizeOf(context).width < _kBreakpointMobile;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            decoration: const BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppTheme.radiusMedium),
                topRight: Radius.circular(AppTheme.radiusMedium),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 14 : 16,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(icon, color: Colors.white),
                  onPressed: onClear,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildCameraCell(BuildContext context, OrderItemInput item, bool isMobile) {
    final width = MediaQuery.sizeOf(context).width;
    final isNarrow = width < _kBreakpointMobile;
    final iconSize = isNarrow ? 18.0 : 22.0;
    final thumbSize = isNarrow ? 36.0 : 44.0;

    if (item.imageUrl != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              width: thumbSize,
              height: thumbSize,
              child: _buildImageWidget(item.imageUrl!, fit: BoxFit.cover),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => item.imageUrl = null),
            icon: Icon(Icons.close, size: iconSize),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      );
    }
    return IconButton(
      onPressed: () async {
        final imageUrl = await ImagePickerHelper.pickAndGetDataUrl(
          context: context,
        );
        if (imageUrl != null && mounted) {
          setState(() => item.imageUrl = imageUrl);
        }
      },
      icon: Icon(Icons.camera_alt, size: iconSize, color: AppTheme.primaryColor),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }

  Widget _buildImageWidget(String imageUrl, {BoxFit fit = BoxFit.cover}) {
    try {
      if (imageUrl.startsWith('data:image/')) {
        final parts = imageUrl.split(',');
        if (parts.length >= 2) {
          final bytes = base64Decode(parts[1]);
          return Image.memory(bytes, fit: fit);
        }
      } else if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
        return Image.network(imageUrl, fit: fit);
      }
    } catch (_) {}
    return Container(
      color: Colors.grey.shade200,
      child: const Icon(Icons.broken_image, color: Colors.grey),
    );
  }

  Widget _buildOrderItemsSection(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < _kBreakpointMobile;
    final isTablet = width >= _kBreakpointMobile && width < _kBreakpointTablet;

    final totalWeight = _orderItems.fold<double>(
      0.0,
      (sum, item) =>
          sum +
          ((double.tryParse(item.weightController.text) ?? 0) *
              (int.tryParse(item.quantityController.text) ?? 0)),
    );
    final totalQty = _orderItems.fold<int>(
      0,
      (sum, item) => sum + (int.tryParse(item.quantityController.text) ?? 0),
    );

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...List.generate(_orderItems.length, (index) {
                  return _buildOrderItemCard(context, index);
                }),
              ],
            )
          else if (isTablet)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildOrderItemsTableHeader(),
                    const SizedBox(height: AppTheme.spacingS),
                    ...List.generate(_orderItems.length, (index) {
                      return _buildOrderItemRow(index, true);
                    }),
                  ],
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildOrderItemsTableHeader(),
                const SizedBox(height: AppTheme.spacingS),
                ...List.generate(_orderItems.length, (index) {
                  return _buildOrderItemRow(index, false);
                }),
              ],
            ),
          const SizedBox(height: AppTheme.spacingM),
          _buildOrderItemsSummary(context, totalWeight, totalQty),
        ],
      ),
    );
  }

  Widget _buildOrderItemCard(BuildContext context, int index) {
    final item = _orderItems[index];
    final isLastRow = index == _orderItems.length - 1;
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      padding: const EdgeInsets.all(AppTheme.spacingS),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _removeOrderItem(index),
                icon: Icon(Icons.delete_outline, color: Colors.grey.shade600),
              ),
              Expanded(
                child: TextFormField(
                  controller: item.nameController,
                  decoration: InputDecoration(
                    hintText: 'Nhập tên món hàng',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: item.unit,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  items: ['Thùng', 'Kiện', 'Bao']
                      .map((u) => DropdownMenuItem(
                            value: u,
                            child: Text(u, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() => item.unit = value ?? 'Thùng');
                  },
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: item.weightController,
                        decoration: InputDecoration(
                          hintText: '0',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 10),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text('KG',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade700)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: item.quantityController,
                  onChanged: (_) {
                    _updateItemAmount(item);
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    hintText: '1',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: TextFormField(
                  controller: item.priceController,
                  onChanged: (_) {
                    _updateItemAmount(item);
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    hintText: '0',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: TextFormField(
                  controller: item.amountController,
                  decoration: InputDecoration(
                    hintText: '0',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  ),
                  keyboardType: TextInputType.number,
                  readOnly: true,
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Flexible(
                child: _buildCameraCell(context, item, true),
              ),
            ],
          ),
          if (isLastRow)
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.spacingS),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _addOrderItem,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Thêm hàng'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOrderItemsSummary(
      BuildContext context, double totalWeight, int totalQty) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < _kBreakpointMobile;

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Tổng: ${_orderItems.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Text(
                '${totalWeight.toStringAsFixed(0)} KG',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Text(
                'Số lượng: $totalQty',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingM),
          _buildCodFields(context),
        ],
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 6,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Tổng: ${_orderItems.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    totalWeight.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: Text(
                    '$totalQty',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: width < _kBreakpointTablet ? 240 : 280,
            child: _buildCodFields(context),
          ),
        ],
      ),
    );
  }

  Widget _buildCodFields(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < _kBreakpointMobile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isMobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Thu hộ tiền hàng',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _codAmountController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  suffixText: 'VND',
                  suffixStyle: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          )
        else
          Row(
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  'Thu hộ tiền hàng',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: TextFormField(
                  controller: _codAmountController,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    suffixText: 'VND',
                    suffixStyle: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        const SizedBox(height: AppTheme.spacingS),
        if (isMobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Phí thu hộ',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _codFeeController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  suffixText: 'VND',
                  suffixStyle: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          )
        else
          Row(
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  'Phí thu hộ',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: TextFormField(
                  controller: _codFeeController,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    suffixText: 'VND',
                    suffixStyle: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildOrderItemsTableHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 44),
        const SizedBox(width: AppTheme.spacingS),
        Expanded(
          flex: 3,
          child: Text(
            'Tên hàng gửi',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spacingS),
        Expanded(
          child: Text(
            'Đơn vị tính',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spacingS),
        Expanded(
          child: Text(
            'Trọng lượng/Thể tích',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spacingS),
        Expanded(
          child: Text(
            'Số lượng',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spacingS),
        Expanded(
          child: Text(
            'Giá cước',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spacingS),
        Expanded(
          child: Text(
            'Thành tiền',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spacingS),
        SizedBox(
          width: 80,
          child: Text(
            'Hình',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spacingS),
        const SizedBox(width: 100),
      ],
    );
  }

  Widget _buildOrderItemRow(int index, bool isNarrowLayout) {
    final item = _orderItems[index];
    final isLastRow = index == _orderItems.length - 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => _removeOrderItem(index),
            icon: Icon(Icons.delete_outline,
                color: Colors.grey.shade600, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: item.nameController,
              decoration: InputDecoration(
                hintText: 'Nhập tên món hàng',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: item.unit,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              items: ['Thùng', 'Kiện', 'Bao']
                  .map((u) => DropdownMenuItem(
                        value: u,
                        child: Text(u, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  item.unit = value ?? 'Thùng';
                });
              },
            ),
          ),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: item.weightController,
                    decoration: InputDecoration(
                      hintText: '0',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 10),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text('KG',
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: TextFormField(
              controller: item.quantityController,
              onChanged: (_) {
                _updateItemAmount(item);
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: '1',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: TextFormField(
              controller: item.priceController,
              onChanged: (_) {
                _updateItemAmount(item);
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: '0',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: TextFormField(
              controller: item.amountController,
              decoration: InputDecoration(
                hintText: '0',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
              keyboardType: TextInputType.number,
              readOnly: true,
            ),
          ),
          const SizedBox(width: AppTheme.spacingS),
          SizedBox(
            width: 80,
            height: 44,
            child: _buildCameraCell(context, item, false),
          ),
          const SizedBox(width: AppTheme.spacingS),
          SizedBox(
            width: 100,
            height: 44,
            child: isLastRow
                ? ElevatedButton(
                    onPressed: _addOrderItem,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('Thêm hàng'),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryPaymentSection(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isNarrow = width < _kBreakpointTablet;

    final routeTripPayment = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          value: _selectedRouteId,
          decoration: const InputDecoration(
            hintText: 'Tuyến lên hàng',
            filled: true,
            fillColor: Colors.white,
          ),
          items: _routes
              .map((r) => DropdownMenuItem<String>(
                    value: r.routeID,
                    child: Text(r.routeName),
                  ))
              .toList(),
          onChanged: (value) {
            setState(() => _selectedRouteId = value);
            _loadTripsForRoute(value);
          },
        ),
        const SizedBox(height: AppTheme.spacingM),
        DropdownButtonFormField<String>(
          value: _selectedTripId,
          decoration: const InputDecoration(
            hintText: 'Chọn chuyến',
            filled: true,
            fillColor: Colors.white,
          ),
          items: _trips
              .map((t) => DropdownMenuItem<String>(
                    value: t.tripID,
                    child: Text(
                        'Chuyến ${t.tripID.length >= 8 ? t.tripID.substring(0, 8) : t.tripID}'),
                  ))
              .toList(),
          onChanged: (value) => setState(() => _selectedTripId = value),
        ),
        const SizedBox(height: AppTheme.spacingM),
        Row(
          children: [
            Text(
              'Hình thức thanh toán',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            const Text(' *', style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: _selectedPaymentMethod,
          decoration: const InputDecoration(
            hintText: 'Chọn cách thanh toán',
            filled: true,
            fillColor: Colors.white,
          ),
          items: ['Tiền mặt', 'Chuyển khoản', 'COD']
              .map((m) => DropdownMenuItem(
                    value: m,
                    child: Text(m),
                  ))
              .toList(),
          onChanged: (value) => setState(() => _selectedPaymentMethod = value),
        ),
      ],
    );

    final paymentSummary = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Thanh toán tiền cước',
              style: TextStyle(color: Colors.blue, fontSize: 14),
            ),
            Text(
              '${_shippingFee.toStringAsFixed(0)} VND',
              style: const TextStyle(color: Colors.blue, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingS),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Tiền cước trả sau và thu hộ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              '${_totalPayment.toStringAsFixed(0)} VND',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isNarrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                routeTripPayment,
                const SizedBox(height: AppTheme.spacingL),
                paymentSummary,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: routeTripPayment,
                ),
                SizedBox(width: AppTheme.spacingXL),
                Expanded(
                  flex: 2,
                  child: paymentSummary,
                ),
              ],
            ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < _kBreakpointMobile;
    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? AppTheme.spacingM : AppTheme.spacingXL,
        vertical: isMobile ? AppTheme.spacingS : AppTheme.spacingM,
      ),
    );
    return Wrap(
      spacing: AppTheme.spacingM,
      runSpacing: AppTheme.spacingM,
      alignment: WrapAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _resetForm,
          style: buttonStyle,
          icon: const Icon(Icons.refresh, size: 20),
          label: const Text('Làm mới'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : () => _saveOrder(),
          style: buttonStyle,
          icon: const Icon(Icons.save, size: 20),
          label: const Text('Lưu'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : () => _saveOrder(createNew: true),
          style: buttonStyle,
          icon: const Icon(Icons.save, size: 20),
          label: const Text('Lưu và tạo mới'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : () => _saveOrder(printOrder: true),
          style: buttonStyle,
          icon: const Icon(Icons.print, size: 20),
          label: const Text('Lưu và in đơn'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : () => _saveOrder(printLabel: true),
          style: buttonStyle,
          icon: const Icon(Icons.label, size: 20),
          label: const Text('Lưu và In tem'),
        ),
      ],
    );
  }
}

class OrderItemInput {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController weightController = TextEditingController();
  final TextEditingController quantityController =
      TextEditingController(text: '1');
  final TextEditingController priceController =
      TextEditingController(text: '0');
  final TextEditingController amountController =
      TextEditingController(text: '0');
  String unit = 'Thùng';
  String? imageUrl;

  void dispose() {
    nameController.dispose();
    weightController.dispose();
    quantityController.dispose();
    priceController.dispose();
    amountController.dispose();
  }
}
