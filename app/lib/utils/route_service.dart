import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Kết quả tuyến đường tham khảo.
class RouteResult {
  final List<LatLng> points;
  final LatLng? origin;
  final LatLng? destination;

  const RouteResult({
    required this.points,
    required this.origin,
    required this.destination,
  });

  bool get hasRoute => points.length >= 2;
}

/// Dịch vụ geocoding và routing tham khảo — không cần API key.
///
/// - Geocoding : Nominatim (bắt buộc kết quả nằm trong Việt Nam)
/// - Routing   : OSRM (router.project-osrm.org)
class RouteService {
  static const _timeout = Duration(seconds: 12);

  static const _headers = {
    'User-Agent': 'GiaoNhanHangApp/1.0 (delivery-management)',
  };

  /// Bounding box của Việt Nam
  static const _vnLatMin = 8.18;
  static const _vnLatMax = 23.40;
  static const _vnLonMin = 102.14;
  static const _vnLonMax = 109.47;

  /// Cache geocoding — xoá bằng [clearCache()] nếu cần reload
  static final _geocodeCache = <String, LatLng?>{};

  static void clearCache() => _geocodeCache.clear();

  // ── Geocoding ─────────────────────────────────────────────────────────────

  /// Chuyển địa chỉ văn bản → [LatLng] trong lãnh thổ Việt Nam.
  /// Trả về null nếu không tìm thấy kết quả hợp lệ.
  static Future<LatLng?> geocode(String address) async {
    final key = address.trim().toLowerCase();
    if (_geocodeCache.containsKey(key)) return _geocodeCache[key];

    // Luôn gắn "Việt Nam" vào query để Nominatim ưu tiên đúng quốc gia
    final query = _withVietnam(address);

    final result = await _geocodeStrategies(query);
    _geocodeCache[key] = result;
    return result;
  }

  static String _withVietnam(String address) {
    final lo = address.toLowerCase();
    if (lo.contains('việt nam') ||
        lo.contains('vietnam') ||
        lo.contains('viet nam')) {
      return address;
    }
    return '$address, Việt Nam';
  }

  /// Thử theo thứ tự:
  ///  1. bounded viewbox + countrycodes=vn  (chính xác nhất)
  ///  2. countrycodes=vn không bounded      (fallback)
  static Future<LatLng?> _geocodeStrategies(String query) async {
    for (final bounded in [true, false]) {
      final result = await _nominatim(query, bounded: bounded);
      if (result != null) return result;
    }
    return null;
  }

  static Future<LatLng?> _nominatim(String query,
      {required bool bounded}) async {
    try {
      final params = <String, String>{
        'q': query,
        'format': 'json',
        'limit': '5',
        'countrycodes': 'vn',
        'accept-language': 'vi',
      };
      if (bounded) {
        params['viewbox'] =
            '$_vnLonMin,$_vnLatMax,$_vnLonMax,$_vnLatMin';
        params['bounded'] = '1';
      }

      final uri =
          Uri.https('nominatim.openstreetmap.org', '/search', params);
      final res =
          await http.get(uri, headers: _headers).timeout(_timeout);
      if (res.statusCode != 200) return null;

      final list = jsonDecode(res.body) as List<dynamic>;
      for (final raw in list) {
        final item = raw as Map<String, dynamic>;
        final lat =
            double.tryParse(item['lat'] as String? ?? '');
        final lon =
            double.tryParse(item['lon'] as String? ?? '');
        if (lat == null || lon == null) continue;

        // Kiểm tra display_name chứa "Việt Nam"
        final displayName =
            (item['display_name'] as String? ?? '').toLowerCase();
        final inVNName = displayName.contains('việt nam') ||
            displayName.contains('vietnam');

        // Kiểm tra toạ độ nằm trong bbox VN
        final inVNBox = lat >= _vnLatMin &&
            lat <= _vnLatMax &&
            lon >= _vnLonMin &&
            lon <= _vnLonMax;

        if (inVNName && inVNBox) return LatLng(lat, lon);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Routing ───────────────────────────────────────────────────────────────

  /// Các mốc trên Quốc lộ 1 dọc bờ biển Việt Nam (từ Bắc → Nam).
  /// Dùng làm waypoint trung gian để OSRM không đi qua Lào/Campuchia.
  static const _vnCoastalWaypoints = [
    (lat: 21.03, lon: 105.85, name: 'Hà Nội'),
    (lat: 20.41, lon: 106.17, name: 'Nam Định'),
    (lat: 19.81, lon: 105.77, name: 'Thanh Hoá'),
    (lat: 18.67, lon: 105.69, name: 'Vinh'),
    (lat: 17.48, lon: 106.60, name: 'Đồng Hới'),
    (lat: 16.47, lon: 107.60, name: 'Huế'),
    (lat: 16.07, lon: 108.22, name: 'Đà Nẵng'),
    (lat: 15.12, lon: 108.80, name: 'Quảng Ngãi'),
    (lat: 13.78, lon: 109.22, name: 'Quy Nhơn'),
    (lat: 13.08, lon: 109.31, name: 'Tuy Hoà'),
    (lat: 12.24, lon: 109.19, name: 'Nha Trang'),
    (lat: 11.56, lon: 108.99, name: 'Phan Rang'),
    (lat: 10.93, lon: 108.10, name: 'Phan Thiết'),
    (lat: 10.78, lon: 106.70, name: 'Hồ Chí Minh'),
  ];

  /// Chọn các waypoint duyên hải nằm giữa lat của [from] và [to].
  /// Chỉ chèn khi tuyến vượt qua vùng eo hẹp miền Trung (dễ bị đi qua Lào).
  static List<LatLng> _buildWaypoints(LatLng from, LatLng to) {
    final minLat = math.min(from.latitude, to.latitude);
    final maxLat = math.max(from.latitude, to.latitude);
    final goingNorth = to.latitude > from.latitude;

    // Chỉ cần waypoint khi tuyến dài & vượt qua vùng eo (lat 12–20°N)
    final spansDanger = minLat < 18.5 && maxLat > 14.0;
    if (!spansDanger) return [from, to];

    // Lọc mốc nằm trong khoảng [minLat, maxLat], thêm biên ±0.5° để tránh
    // loại bỏ mốc gần điểm đầu/cuối
    final mid = _vnCoastalWaypoints
        .where((w) => w.lat > minLat - 0.5 && w.lat < maxLat + 0.5)
        .map((w) => LatLng(w.lat, w.lon))
        .toList();

    // Sắp xếp cùng hướng với tuyến (Bắc→Nam hoặc Nam→Bắc)
    mid.sort((a, b) => goingNorth
        ? a.latitude.compareTo(b.latitude)
        : b.latitude.compareTo(a.latitude));

    return [from, ...mid, to];
  }

  static Future<List<LatLng>> getRoute(LatLng from, LatLng to) async {
    if (!_inVN(from) || !_inVN(to)) return [];

    final waypoints = _buildWaypoints(from, to);

    try {
      // Nối tất cả waypoint thành chuỗi OSRM: "lon,lat;lon,lat;..."
      final coords = waypoints
          .map((w) => '${w.longitude},${w.latitude}')
          .join(';');

      final uri = Uri.https(
        'router.project-osrm.org',
        '/route/v1/driving/$coords',
        {'overview': 'full', 'geometries': 'geojson'},
      );
      final res =
          await http.get(uri, headers: _headers).timeout(_timeout);
      if (res.statusCode != 200) return [from, to];

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return [from, to];

      final geometry =
          routes.first['geometry'] as Map<String, dynamic>;
      final pts = geometry['coordinates'] as List<dynamic>;
      if (pts.isEmpty) return [from, to];

      final points = pts
          .map((c) => LatLng(
                (c[1] as num).toDouble(),
                (c[0] as num).toDouble(),
              ))
          .toList();

      // Sanity: khoảng cách tuyến không quá 5× đường thẳng
      final routeKm = (routes.first['distance'] as num) / 1000.0;
      final straightKm = _haversineKm(from, to);
      if (straightKm > 1 && routeKm > straightKm * 5) {
        return [from, to];
      }

      return points;
    } catch (_) {
      return [from, to];
    }
  }

  // ── Combined ─────────────────────────────────────────────────────────────

  static Future<RouteResult> fetchReferenceRoute(
    String originAddress,
    String destAddress,
  ) async {
    final origin = await geocode(originAddress);
    final destination = await geocode(destAddress);

    if (origin == null || destination == null) {
      return RouteResult(
          points: [], origin: origin, destination: destination);
    }

    final points = await getRoute(origin, destination);
    return RouteResult(
        points: points, origin: origin, destination: destination);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static bool _inVN(LatLng p) =>
      p.latitude >= _vnLatMin &&
      p.latitude <= _vnLatMax &&
      p.longitude >= _vnLonMin &&
      p.longitude <= _vnLonMax;

  static double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(a.latitude)) *
            math.cos(_rad(b.latitude)) *
            math.pow(math.sin(dLon / 2), 2);
    return 2 * r * math.asin(math.sqrt(h.toDouble()));
  }

  static double _rad(double d) => d * math.pi / 180;
}
