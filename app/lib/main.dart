import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'config/api_config.dart';
import 'screens/login_screen.dart';
import 'screens/staff_management_screen.dart';
import 'screens/sender_management_screen.dart';
import 'screens/receiver_management_screen.dart';
import 'screens/route_management_screen.dart';
import 'screens/trip_management_screen.dart';
import 'screens/create_order_screen.dart';
import 'screens/outgoing_warehouse_screen.dart';
import 'screens/distribute_screen.dart';
import 'screens/incoming_warehouse_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/config_screen.dart';
import 'ui/navigation_drawer.dart';
import 'ui/design_system.dart';

void main() {
  final baseUrl = ApiConfig.baseUrl;
  runApp(GiaoNhanHangApp(baseUrl: baseUrl));
}

class GiaoNhanHangApp extends StatelessWidget {
  const GiaoNhanHangApp({super.key, required this.baseUrl});
  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Giao Nhận Hàng',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        primaryColor: AppTheme.primaryColor,
        useMaterial3: true,
      ),
      home: HomeView(baseUrl: baseUrl),
      debugShowCheckedModeBanner: false,
    );
  }
}

enum _HomeView {
  staffManagement,
  senderManagement,
  receiverManagement,
  routeManagement,
  tripManagement,
  createOrder,
  outgoingWarehouse,
  distribute,
  incomingWarehouse,
  reports,
  config,
}

class HomeView extends StatefulWidget {
  const HomeView({super.key, required this.baseUrl});
  final String baseUrl;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late final ApiClient api = ApiClient(baseUrl: widget.baseUrl);
  _HomeView _view = _HomeView.createOrder;
  bool _isLoggedIn = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    setState(() {
      _isLoggedIn = token != null && token.isNotEmpty;
    });
  }

  void _handleLoginSuccess() {
    setState(() {
      _isLoggedIn = true;
    });
  }

  void _handleLogout() async {
    await api.logout();
    setState(() {
      _isLoggedIn = false;
    });
  }

  void _onItemSelected(int index) {
    setState(() {
      _view = _HomeView.values[index];
    });
    _scaffoldKey.currentState?.closeDrawer();
  }

  Widget _getCurrentScreen() {
    switch (_view) {
      case _HomeView.staffManagement:
        return StaffManagementScreen(api: api);
      case _HomeView.senderManagement:
        return SenderManagementScreen(api: api);
      case _HomeView.receiverManagement:
        return ReceiverManagementScreen(api: api);
      case _HomeView.routeManagement:
        return RouteManagementScreen(api: api);
      case _HomeView.tripManagement:
        return TripManagementScreen(api: api);
      case _HomeView.createOrder:
        return CreateOrderScreen(api: api);
      case _HomeView.outgoingWarehouse:
        return OutgoingWarehouseScreen(api: api);
      case _HomeView.distribute:
        return DistributeScreen(api: api);
      case _HomeView.incomingWarehouse:
        return IncomingWarehouseScreen(api: api);
      case _HomeView.reports:
        return ReportsScreen(api: api);
      case _HomeView.config:
        return ConfigScreen(api: api);
    }
  }

  int _getSelectedIndex() {
    return _HomeView.values.indexOf(_view);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoggedIn) {
      return LoginScreen(
        api: api,
        onLoginSuccess: _handleLoginSuccess,
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Giao Nhận Hàng'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      drawer: AppNavigationDrawer(
        selectedIndex: _getSelectedIndex(),
        onItemSelected: _onItemSelected,
        onLogout: _handleLogout,
      ),
      body: _getCurrentScreen(),
    );
  }
}
