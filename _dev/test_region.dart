import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

// 复制 _pointInRing / _haversineKm 逻辑验证
void main() {
  final raw = File('assets/data/china_regions.json').readAsStringSync();
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final provinces = (json['province'] as List).cast<Map<String, dynamic>>();

  for (final p in provinces) {
    final ring = (p['polygon'] as List).cast<List>();
    final List<List<double>> pairs = ring
        .where((e) => e.length >= 2)
        .map((e) => <double>[e[0].toDouble(), e[1].toDouble()])
        .toList();
    final name = p['name'];

    double minLng = double.infinity, minLat = double.infinity;
    double maxLng = -double.infinity, maxLat = -double.infinity;
    for (final pt in pairs) {
      if (pt[0] < minLng) minLng = pt[0];
      if (pt[0] > maxLng) maxLng = pt[0];
      if (pt[1] < minLat) minLat = pt[1];
      if (pt[1] > maxLat) maxLat = pt[1];
    }
    print(
        '$name: bbox=[$minLng, $minLat, $maxLng, $maxLat] pts=${pairs.length}');
  }

  print('---');
  // 测试青岛坐标
  final lat = 36.0789;
  final lng = 120.3414;
  print('test point: lat=$lat, lng=$lng');

  // 测试一系列已知坐标
  final tests = [
    {'name': '北京天安门', 'lat': 39.9087, 'lng': 116.3974},
    {'name': '上海外滩', 'lat': 31.2397, 'lng': 121.4905},
    {'name': '广州塔', 'lat': 23.1066, 'lng': 113.3215},
    {'name': '成都春熙路', 'lat': 30.6586, 'lng': 104.0649},
    {'name': '西安钟楼', 'lat': 34.3416, 'lng': 108.9398},
    {'name': '哈尔滨', 'lat': 45.8038, 'lng': 126.5350},
    {'name': '拉萨', 'lat': 29.6500, 'lng': 91.1000},
    {'name': '青岛栈桥', 'lat': 36.0789, 'lng': 120.3414},
    {'name': '杭州西湖', 'lat': 30.2741, 'lng': 120.1551},
    {'name': '武汉黄鹤楼', 'lat': 30.5445, 'lng': 114.3055},
    {'name': '深圳', 'lat': 22.5431, 'lng': 114.0579},
    {'name': '天津', 'lat': 39.1255, 'lng': 117.1902},
  ];
  for (final t in tests) {
    final tlat = (t['lat'] as num).toDouble();
    final tlng = (t['lng'] as num).toDouble();
    String? hit;
    for (final p in provinces) {
      final ring = (p['polygon'] as List).cast<List>();
      final List<List<double>> pairs = ring
          .where((e) => e.length >= 2)
          .map((e) => <double>[e[0].toDouble(), e[1].toDouble()])
          .toList();
      double minLng = double.infinity, minLat = double.infinity;
      double maxLng = -double.infinity, maxLat = -double.infinity;
      for (final pt in pairs) {
        if (pt[0] < minLng) minLng = pt[0];
        if (pt[0] > maxLng) maxLng = pt[0];
        if (pt[1] < minLat) minLat = pt[1];
        if (pt[1] > maxLat) maxLat = pt[1];
      }
      if (tlng < minLng || tlng > maxLng) continue;
      if (tlat < minLat || tlat > maxLat) continue;
      if (_pointInRing(tlng, tlat, pairs)) {
        hit = p['name'] as String;
        break;
      }
    }
    // 加 PNP 兜底：找最近省份中心，500km 内即采纳
    if (hit == null) {
      String? nearestName;
      double nearestKm = double.infinity;
      for (final p in provinces) {
        final center = (p['center'] as List).cast<num>();
        final d = _haversineKm(
            tlat, tlng, center[1].toDouble(), center[0].toDouble());
        if (d < nearestKm) {
          nearestKm = d;
          nearestName = p['name'] as String;
        }
      }
      if (nearestName != null && nearestKm <= 500) {
        hit = '$nearestName (📏回退 ${nearestKm.toStringAsFixed(0)}km)';
      }
    }
    print('${t['name']} ($tlat, $tlng) → ${hit ?? "❌ 未命中"}');
  }
  for (final p in provinces) {
    final ring = (p['polygon'] as List).cast<List>();
    final List<List<double>> pairs = ring
        .where((e) => e.length >= 2)
        .map((e) => <double>[e[0].toDouble(), e[1].toDouble()])
        .toList();

    double minLng = double.infinity, minLat = double.infinity;
    double maxLng = -double.infinity, maxLat = -double.infinity;
    for (final pt in pairs) {
      if (pt[0] < minLng) minLng = pt[0];
      if (pt[0] > maxLng) maxLng = pt[0];
      if (pt[1] < minLat) minLat = pt[1];
      if (pt[1] > maxLat) maxLat = pt[1];
    }
    if (lng < minLng || lng > maxLng) continue;
    if (lat < minLat || lat > maxLat) continue;

    final inside = _pointInRing(lng, lat, pairs);
    if (inside) {
      print('HIT: ${p['name']}');
    }
  }
}

bool _pointInRing(double lng, double lat, List<List<double>> ring) {
  var inside = false;
  final n = ring.length;
  for (var i = 0, j = n - 1; i < n; j = i++) {
    final xi = ring[i][0], yi = ring[i][1];
    final xj = ring[j][0], yj = ring[j][1];
    final intersect = ((yi > lat) != (yj > lat)) &&
        (lng <
            (xj - xi) * (lat - yi) / ((yj - yi) == 0 ? 1e-12 : (yj - yi)) + xi);
    if (intersect) inside = !inside;
  }
  return inside;
}

double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  const rad = 3.141592653589793 / 180.0;
  final dLat = (lat2 - lat1) * rad;
  final dLng = (lng2 - lng1) * rad;
  final a = (1 - math.cos(dLat)) / 2 +
      math.cos(lat1 * rad) * math.cos(lat2 * rad) * (1 - math.cos(dLng)) / 2;
  return 2 * r * math.asin(math.sqrt(a));
}
