// ============================================================
// lib/src/services/service_region_resolver.dart
// 离线 EXIF GPS → 省 / 市 / 区县 反查
//
// 工作机制：
//   1) 启动时一次性加载 assets/data/china_regions.json
//   2) 解析所有省级多边形（含 bbox 预剪枝）
//   3) 解析所有市级中心点
//   4) 解析所有区县级中心点（新增 v2.0）
//   5) resolve(lng, lat) 时：
//        - 先用 bbox 过滤候选省份（O(1)）
//        - 射线法 PNP 判断点是否在多边形内（O(n)）
//        - 命中省级后，再按中心点距离匹配最近市级
//        - 命中市级后，再按中心点距离匹配最近区县级
//   6) 数据是 GeoJSON 风格（[lng, lat] 顺序）
//   7) 坐标系: GCJ-02（高德坐标系，与 GPS/WGS-84 有偏移）
//
// 性能：34 省级多边形 × 平均 343 点 + 395 市级 + 2830 区县级
//       射线法 < 1ms / 次；整体 resolve < 2ms / 次
// ============================================================
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart' show rootBundle;

/// 反查结果：省/市/区县 三段 + 距离信息
class RegionInfo {
  /// 省 / 自治区 / 直辖市名
  final String province;

  /// 市 / 地区名（中心点匹配时才有；纯省级命中时为 null）
  final String? city;

  /// 县 / 区（区县级中心点匹配，v2.0 新增）
  final String? district;

  /// 中心点匹配城市时，到该城市中心的直线距离（km）
  final double? cityDistanceKm;

  /// 中心点匹配区县时，到该区县中心的直线距离（km）
  final double? districtDistanceKm;

  const RegionInfo({
    required this.province,
    this.city,
    this.district,
    this.cityDistanceKm,
    this.districtDistanceKm,
  });

  /// 供 ExifData.cityName 存储的规范字符串：省/市/区县
  String get fullName {
    final parts = <String>[province];
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (district != null && district!.isNotEmpty) parts.add(district!);
    return parts.join('/');
  }

  @override
  String toString() => 'RegionInfo($fullName)';
}

/// 单个省级多边形特征
class _ProvinceFeature {
  final String name;
  final String adcode;
  final List<double> center; // [lng, lat]
  final List<double> bbox; // [minLng, minLat, maxLng, maxLat]
  final List<List<double>> ring; // [[lng, lat], ...] 闭合多边形
  _ProvinceFeature({
    required this.name,
    required this.adcode,
    required this.center,
    required this.bbox,
    required this.ring,
  });
}

/// 单个市级中心
class _CityPoint {
  final String name;
  final String province;
  final String adcode;
  final double lng;
  final double lat;
  _CityPoint({
    required this.name,
    required this.province,
    required this.adcode,
    required this.lng,
    required this.lat,
  });
}

/// 单个区县级中心（v2.0 新增）
class _DistrictPoint {
  final String name;
  final String province;
  final String city;
  final String adcode;
  final double lng;
  final double lat;
  _DistrictPoint({
    required this.name,
    required this.province,
    required this.city,
    required this.adcode,
    required this.lng,
    required this.lat,
  });
}

/// 离线反查服务（单例：app 进程内只需一份缓存）
class RegionResolver {
  RegionResolver._();
  static final RegionResolver instance = RegionResolver._();

  bool _loaded = false;
  List<_ProvinceFeature> _provinces = const [];
  List<_CityPoint> _cities = const [];
  List<_DistrictPoint> _districts = const [];

  /// 加载 JSON（首次调用时执行；之后 noop）
  Future<void> load(
      {String assetPath = 'assets/data/china_regions.json'}) async {
    if (_loaded) return;
    final raw = await rootBundle.loadString(assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;

    // 解析省级
    _provinces = ((json['province'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(_parseProvince)
        .whereType<_ProvinceFeature>()
        .toList(growable: false);

    // 解析市级
    _cities = ((json['city'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(_parseCity)
        .whereType<_CityPoint>()
        .toList(growable: false);

    // 解析区县级（v2.0 新增）
    _districts = ((json['district'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(_parseDistrict)
        .whereType<_DistrictPoint>()
        .toList(growable: false);

    _loaded = true;
  }

  /// 强制重新加载（用于运行时切换数据源）
  Future<void> reload(
      {String assetPath = 'assets/data/china_regions.json'}) async {
    _loaded = false;
    _provinces = const [];
    _cities = const [];
    _districts = const [];
    await load(assetPath: assetPath);
  }

  /// 主入口：把经纬度反查为行政区划
  ///
  /// [lat] 纬度
  /// [lng] 经度
  /// [cityMatchRadiusKm] 市级中心点匹配半径（默认 100km）
  /// [districtMatchRadiusKm] 区县级中心点匹配半径（默认 30km）
  ///
  /// 匹配行为：
  ///   省级：bbox + 射线法精筛
  ///   市级：同省内最近中心，距离 > 阈值仍返回最近市
  ///   区县级：同市内最近中心，距离 > 阈值仍返回最近区县
  RegionInfo? resolve(double lat, double lng,
      {double cityMatchRadiusKm = 100.0, double districtMatchRadiusKm = 30.0}) {
    if (!_loaded || _provinces.isEmpty) return null;

    // 1) 省级：bbox 粗筛 + 射线法 PNP 精筛
    _ProvinceFeature? hit;
    for (final p in _provinces) {
      if (lng < p.bbox[0] || lng > p.bbox[2]) continue;
      if (lat < p.bbox[1] || lat > p.bbox[3]) continue;
      if (_pointInRing(lng, lat, p.ring)) {
        hit = p;
        break; // 省级互斥，找到第一个即可
      }
    }

    // 1.5) PNP 未命中：回退到「最近省份中心」兜底
    hit ??= _nearestProvinceWithin(lat, lng, 500.0);
    if (hit == null) return null;

    // 2) 市级：在同省内找最近中心
    _CityPoint? nearestCity;
    double nearestCityKm = double.infinity;
    for (final c in _cities) {
      if (c.province != hit.name) continue;
      final d = _haversineKm(lat, lng, c.lat, c.lng);
      if (d < nearestCityKm) {
        nearestCityKm = d;
        nearestCity = c;
      }
    }

    // 3) 区县级：在同市内找最近中心（v2.0 新增）
    _DistrictPoint? nearestDistrict;
    double nearestDistrictKm = double.infinity;
    if (nearestCity != null) {
      for (final d in _districts) {
        if (d.province != hit.name || d.city != nearestCity.name) continue;
        final dist = _haversineKm(lat, lng, d.lat, d.lng);
        if (dist < nearestDistrictKm) {
          nearestDistrictKm = dist;
          nearestDistrict = d;
        }
      }
    }

    return RegionInfo(
      province: hit.name,
      city: nearestCity?.name,
      district: nearestDistrict?.name,
      cityDistanceKm: nearestCity == null ? null : nearestCityKm,
      districtDistanceKm: nearestDistrict == null ? null : nearestDistrictKm,
    );
  }

  /// 当前加载的各级数量（调试用）
  int get provinceCount => _provinces.length;
  int get cityCount => _cities.length;
  int get districtCount => _districts.length;
  bool get isLoaded => _loaded;

  /// 找最近且在 [maxKm] 之内的省份；用于 PNP 失败时的兜底。
  _ProvinceFeature? _nearestProvinceWithin(
      double lat, double lng, double maxKm) {
    _ProvinceFeature? best;
    double bestKm = double.infinity;
    for (final p in _provinces) {
      final d = _haversineKm(lat, lng, p.center[1], p.center[0]);
      if (d < bestKm) {
        bestKm = d;
        best = p;
      }
    }
    return (best != null && bestKm <= maxKm) ? best : null;
  }

  // ─────────── 内部实现 ───────────

  _ProvinceFeature? _parseProvince(Map<String, dynamic> m) {
    try {
      final name = m['name'] as String?;
      final adcode = m['adcode'] as String? ?? '';
      final center = (m['center'] as List?)?.cast<num>();
      final ring = (m['polygon'] as List?)?.cast<List>();
      if (name == null || center == null) return null;
      // polygon 字段可选：无多边形时仍可作为省级中心点匹配
      if (ring == null || ring.isEmpty) {
        final cLng = center[0].toDouble();
        final cLat = center[1].toDouble();
        return _ProvinceFeature(
          name: name,
          adcode: adcode,
          center: [cLng, cLat],
          bbox: [cLng, cLat, cLng, cLat],
          ring: const [],
        );
      }

      final ringPairs = ring
          .where((p) => p.length >= 2)
          .map((p) => <double>[p[0].toDouble(), p[1].toDouble()])
          .toList(growable: false);
      if (ringPairs.length < 3) {
        // 多边形点太少，退化为中心点
        final cLng = center[0].toDouble();
        final cLat = center[1].toDouble();
        return _ProvinceFeature(
          name: name,
          adcode: adcode,
          center: [cLng, cLat],
          bbox: [cLng, cLat, cLng, cLat],
          ring: const [],
        );
      }

      // 预计算 bbox
      double minLng = double.infinity, minLat = double.infinity;
      double maxLng = -double.infinity, maxLat = -double.infinity;
      for (final p in ringPairs) {
        if (p[0] < minLng) minLng = p[0];
        if (p[0] > maxLng) maxLng = p[0];
        if (p[1] < minLat) minLat = p[1];
        if (p[1] > maxLat) maxLat = p[1];
      }
      return _ProvinceFeature(
        name: name,
        adcode: adcode,
        center: [center[0].toDouble(), center[1].toDouble()],
        bbox: [minLng, minLat, maxLng, maxLat],
        ring: ringPairs,
      );
    } catch (_) {
      return null;
    }
  }

  _CityPoint? _parseCity(Map<String, dynamic> m) {
    try {
      final name = m['name'] as String?;
      final province = m['province'] as String?;
      final adcode = m['adcode'] as String? ?? '';
      final center = (m['center'] as List?)?.cast<num>();
      if (name == null || province == null || center == null) return null;
      return _CityPoint(
        name: name,
        province: province,
        adcode: adcode,
        lng: center[0].toDouble(),
        lat: center[1].toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  _DistrictPoint? _parseDistrict(Map<String, dynamic> m) {
    try {
      final name = m['name'] as String?;
      final province = m['province'] as String?;
      final city = m['city'] as String?;
      final adcode = m['adcode'] as String? ?? '';
      final center = (m['center'] as List?)?.cast<num>();
      if (name == null || province == null || city == null || center == null) {
        return null;
      }
      return _DistrictPoint(
        name: name,
        province: province,
        city: city,
        adcode: adcode,
        lng: center[0].toDouble(),
        lat: center[1].toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  /// 射线法：判断点 (lng, lat) 是否在多边形 ring 内
  bool _pointInRing(double lng, double lat, List<List<double>> ring) {
    if (ring.isEmpty) return false;
    var inside = false;
    final n = ring.length;
    for (var i = 0, j = n - 1; i < n; j = i++) {
      final xi = ring[i][0], yi = ring[i][1];
      final xj = ring[j][0], yj = ring[j][1];
      final intersect = ((yi > lat) != (yj > lat)) &&
          (lng <
              (xj - xi) * (lat - yi) / ((yj - yi) == 0 ? 1e-12 : (yj - yi)) +
                  xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  /// Haversine 球面距离（km）
  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.min(1.0, math.sqrt(a)));
  }

  double _toRad(double deg) => deg * math.pi / 180.0;
}
