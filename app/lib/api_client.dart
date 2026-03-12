import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  ApiClient({required this.baseUrl});
  final String baseUrl;

  final http.Client _client = http.Client();
  static const Duration _timeout = Duration(seconds: 10);

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  void _check(http.Response r, {bool expect201 = false, bool expect204 = false}) {
    if (expect201 && r.statusCode != 201) {
      throw Exception('Expected 201, got ${r.statusCode}: ${r.body}');
    } else if (expect204 && r.statusCode != 204) {
      throw Exception('Expected 204, got ${r.statusCode}: ${r.body}');
    } else if (!expect201 && !expect204 && r.statusCode >= 400) {
      throw Exception('HTTP ${r.statusCode}: ${r.body}');
    }
  }

  Future<String> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null || token.isEmpty) {
      throw Exception('No authentication token found');
    }
    return token;
  }

  // Auth methods
  Future<CheckEmailResponse> checkEmail(String email) async {
    final r = await _client
        .post(_u('/auth/check-email'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(CheckEmailRequest(email: email).toJson()))
        .timeout(_timeout);
    if (r.statusCode >= 400) {
      String msg = 'Không thể kiểm tra email. Vui lòng thử lại sau.';
      try {
        final body = jsonDecode(r.body) as Map<String, dynamic>?;
        if (body != null && body['message'] != null) {
          msg = body['message'] as String;
        }
      } catch (_) {}
      throw Exception(msg);
    }
    return CheckEmailResponse.fromJson(jsonDecode(r.body));
  }

  Future<LoginResponse> login(LoginRequest request) async {
    final r = await _client
        .post(_u('/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(request.toJson()))
        .timeout(_timeout);
    _check(r);

    final response = LoginResponse.fromJson(jsonDecode(r.body));
    final prefs = await SharedPreferences.getInstance();
    if (response.token != null) {
      await prefs.setString('jwt_token', response.token!);
    }
    if (response.refreshToken != null) {
      await prefs.setString('refresh_token', response.refreshToken!);
    }
    await prefs.setString('user_role', response.userRole ?? 'shop_owner');
    await prefs.setString('user_email', request.email);
    await prefs.setString('user_login', request.userLogin);
    await prefs.setString('password_login', request.passwordLogin);
    if (response.databaseName != null) {
      await prefs.setString('database_name', response.databaseName!);
    }

    return response;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_role');
    await prefs.remove('user_email');
    await prefs.remove('user_login');
    await prefs.remove('password_login');
    await prefs.remove('database_name');
  }

  // Orders
  Future<List<Order>> getOrders() async {
    final jwtToken = await _getAuthToken();
    final r = await _client.get(_u('/orders'), headers: {
      'Authorization': 'Bearer $jwtToken',
      'Content-Type': 'application/json',
    }).timeout(_timeout);
    _check(r);
    final list = jsonDecode(r.body) as List;
    return list.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Order> getOrder(String id) async {
    final jwtToken = await _getAuthToken();
    final r = await _client.get(_u('/orders/$id'), headers: {
      'Authorization': 'Bearer $jwtToken',
      'Content-Type': 'application/json',
    }).timeout(_timeout);
    _check(r);
    return Order.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<Order> createOrder(CreateOrderRequest request) async {
    final jwtToken = await _getAuthToken();
    final r = await _client.post(_u('/orders'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(request.toJson())).timeout(_timeout);
    _check(r, expect201: true);
    return Order.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> updateOrder(String id, CreateOrderRequest request) async {
    final jwtToken = await _getAuthToken();
    final r = await _client.put(_u('/orders/$id'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(request.toJson())).timeout(_timeout);
    _check(r, expect204: true);
  }

  Future<void> deleteOrder(String id) async {
    final jwtToken = await _getAuthToken();
    final r = await _client.delete(_u('/orders/$id'), headers: {
      'Authorization': 'Bearer $jwtToken',
      'Content-Type': 'application/json',
    }).timeout(_timeout);
    _check(r, expect204: true);
  }

  // Senders
  Future<List<Sender>> getSenders() async {
    final jwtToken = await _getAuthToken();
    final r = await _client.get(_u('/senders'), headers: {
      'Authorization': 'Bearer $jwtToken',
      'Content-Type': 'application/json',
    }).timeout(_timeout);
    _check(r);
    final list = jsonDecode(r.body) as List;
    return list.map((e) => Sender.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Sender> createSender(Sender sender) async {
    final jwtToken = await _getAuthToken();
    final r = await _client.post(_u('/senders'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(sender.toJson())).timeout(_timeout);
    _check(r, expect201: true);
    return Sender.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<List<Sender>> searchSendersByPhone(String query) async {
    final jwtToken = await _getAuthToken();
    final encoded = Uri.encodeComponent(query.trim());
    final r = await _client.get(_u('/senders?phone=$encoded'), headers: {
      'Authorization': 'Bearer $jwtToken',
      'Content-Type': 'application/json',
    }).timeout(_timeout);
    _check(r);
    final list = jsonDecode(r.body) as List;
    return list.map((e) => Sender.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> updateSender(String id, Sender sender) async {
    final jwtToken = await _getAuthToken();
    final r = await _client.put(_u('/senders/$id'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(sender.toJson())).timeout(_timeout);
    _check(r, expect204: true);
  }

  Future<void> deleteSender(String id) async {
    final jwtToken = await _getAuthToken();
    final r = await _client.delete(_u('/senders/$id'), headers: {
      'Authorization': 'Bearer $jwtToken',
      'Content-Type': 'application/json',
    }).timeout(_timeout);
    _check(r, expect204: true);
  }

  // Receivers
  Future<List<Receiver>> getReceivers() async {
    final jwtToken = await _getAuthToken();
    final r = await _client.get(_u('/receivers'), headers: {
      'Authorization': 'Bearer $jwtToken',
      'Content-Type': 'application/json',
    }).timeout(_timeout);
    _check(r);
    final list = jsonDecode(r.body) as List;
    return list.map((e) => Receiver.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Receiver> createReceiver(Receiver receiver) async {
    final jwtToken = await _getAuthToken();
    final r = await _client.post(_u('/receivers'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(receiver.toJson())).timeout(_timeout);
    _check(r, expect201: true);
    return Receiver.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<List<Receiver>> searchReceiversByPhone(String query) async {
    final jwtToken = await _getAuthToken();
    final encoded = Uri.encodeComponent(query.trim());
    final r = await _client.get(_u('/receivers?phone=$encoded'), headers: {
      'Authorization': 'Bearer $jwtToken',
      'Content-Type': 'application/json',
    }).timeout(_timeout);
    _check(r);
    final list = jsonDecode(r.body) as List;
    return list.map((e) => Receiver.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> updateReceiver(String id, Receiver receiver) async {
    final jwtToken = await _getAuthToken();
    final r = await _client.put(_u('/receivers/$id'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(receiver.toJson())).timeout(_timeout);
    _check(r, expect204: true);
  }

  Future<void> deleteReceiver(String id) async {
    final jwtToken = await _getAuthToken();
    final r = await _client.delete(_u('/receivers/$id'), headers: {
      'Authorization': 'Bearer $jwtToken',
      'Content-Type': 'application/json',
    }).timeout(_timeout);
    _check(r, expect204: true);
  }

  // Branches
  Future<List<Branch>> getBranches() async {
    final jwtToken = await _getAuthToken();
    final r = await _client.get(_u('/branches'), headers: {
      'Authorization': 'Bearer $jwtToken',
      'Content-Type': 'application/json',
    }).timeout(_timeout);
    _check(r);
    final list = jsonDecode(r.body) as List;
    return list.map((e) => Branch.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Branch> createBranch(Branch branch) async {
    final jwtToken = await _getAuthToken();
    final r = await _client.post(_u('/branches'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(branch.toJson())).timeout(_timeout);
    _check(r, expect201: true);
    return Branch.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  // Staff
  Future<List<Staff>> getStaff() async {
    final jwtToken = await _getAuthToken();
    final r = await _client.get(_u('/staff'), headers: {
      'Authorization': 'Bearer $jwtToken',
      'Content-Type': 'application/json',
    }).timeout(_timeout);
    _check(r);
    final list = jsonDecode(r.body) as List;
    return list.map((e) => Staff.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Staff> createStaff(Staff staff) async {
    final jwtToken = await _getAuthToken();
    final r = await _client.post(_u('/staff'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(staff.toJson())).timeout(_timeout);
    _check(r, expect201: true);
    return Staff.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> updateStaff(String id, Staff staff) async {
    final jwtToken = await _getAuthToken();
    final r = await _client.put(_u('/staff/$id'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(staff.toJson())).timeout(_timeout);
    _check(r, expect204: true);
  }

  Future<void> deleteStaff(String id) async {
    final jwtToken = await _getAuthToken();
    final r = await _client.delete(_u('/staff/$id'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json'
        }).timeout(_timeout);
    _check(r, expect204: true);
  }

  // Routes
  Future<List<Route>> getRoutes() async {
    final jwtToken = await _getAuthToken();
    final r = await _client.get(_u('/routes'), headers: {
      'Authorization': 'Bearer $jwtToken',
      'Content-Type': 'application/json',
    }).timeout(_timeout);
    _check(r);
    final list = jsonDecode(r.body) as List;
    return list.map((e) => Route.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Route> createRoute(Route route) async {
    final jwtToken = await _getAuthToken();
    final r = await _client.post(_u('/routes'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(route.toJson())).timeout(_timeout);
    _check(r, expect201: true);
    return Route.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> updateRoute(String id, Route route) async {
    final jwtToken = await _getAuthToken();
    final r = await _client.put(_u('/routes/$id'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(route.toJson())).timeout(_timeout);
    _check(r, expect204: true);
  }

  Future<void> deleteRoute(String id) async {
    final jwtToken = await _getAuthToken();
    final r = await _client.delete(_u('/routes/$id'), headers: {
      'Authorization': 'Bearer $jwtToken',
      'Content-Type': 'application/json',
    }).timeout(_timeout);
    _check(r, expect204: true);
  }

  // Trips
  Future<List<Trip>> getTrips({String? routeId}) async {
    final jwtToken = await _getAuthToken();
    final url = routeId != null ? '/trips?routeId=$routeId' : '/trips';
    final r = await _client.get(_u(url), headers: {
      'Authorization': 'Bearer $jwtToken',
      'Content-Type': 'application/json',
    }).timeout(_timeout);
    _check(r);
    final list = jsonDecode(r.body) as List;
    return list.map((e) => Trip.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Trip> createTrip(Trip trip) async {
    final jwtToken = await _getAuthToken();
    final r = await _client.post(_u('/trips'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(trip.toJson())).timeout(_timeout);
    _check(r, expect201: true);
    return Trip.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> updateTrip(String id, Trip trip) async {
    final jwtToken = await _getAuthToken();
    final r = await _client.put(_u('/trips/$id'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(trip.toJson())).timeout(_timeout);
    _check(r, expect204: true);
  }

  Future<void> deleteTrip(String id) async {
    final jwtToken = await _getAuthToken();
    final r = await _client.delete(_u('/trips/$id'), headers: {
      'Authorization': 'Bearer $jwtToken',
      'Content-Type': 'application/json',
    }).timeout(_timeout);
    _check(r, expect204: true);
  }

  // Vehicles
  Future<List<Vehicle>> getVehicles() async {
    final jwtToken = await _getAuthToken();
    final r = await _client.get(_u('/vehicles'), headers: {
      'Authorization': 'Bearer $jwtToken',
      'Content-Type': 'application/json',
    }).timeout(_timeout);
    _check(r);
    final list = jsonDecode(r.body) as List;
    return list.map((e) => Vehicle.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Vehicle> createVehicle(Vehicle vehicle) async {
    final jwtToken = await _getAuthToken();
    final r = await _client.post(_u('/vehicles'),
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(vehicle.toJson())).timeout(_timeout);
    _check(r, expect201: true);
    return Vehicle.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  // ──────────────────────────────────────────────
  // Location Tracking (REST fallback)
  // ──────────────────────────────────────────────

  /// Gửi vị trí mới lên server (fallback khi không dùng SignalR)
  Future<void> updateLocation(LocationUpdateRequest req) async {
    final jwtToken = await _getAuthToken();
    final r = await _client
        .post(
          _u('/location/update'),
          headers: {
            'Authorization': 'Bearer $jwtToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(req.toJson()),
        )
        .timeout(_timeout);
    _check(r);
  }

  /// Dừng chia sẻ vị trí
  Future<void> stopLocationSharing(LocationStopRequest req) async {
    final jwtToken = await _getAuthToken();
    final r = await _client
        .post(
          _u('/location/stop'),
          headers: {
            'Authorization': 'Bearer $jwtToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(req.toJson()),
        )
        .timeout(_timeout);
    _check(r);
  }

  /// Lấy vị trí mới nhất của tất cả staff đang active
  Future<List<StaffLocationDto>> getActiveLocations() async {
    final jwtToken = await _getAuthToken();
    final r = await _client.get(_u('/location/active'), headers: {
      'Authorization': 'Bearer $jwtToken',
      'Content-Type': 'application/json',
    }).timeout(_timeout);
    _check(r);
    final list = jsonDecode(r.body) as List;
    return list
        .map((e) => StaffLocationDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Lấy token xác thực để kết nối SignalR
  Future<String> getAuthToken() => _getAuthToken();
}
