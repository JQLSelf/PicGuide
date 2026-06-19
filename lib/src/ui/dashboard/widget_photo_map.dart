// ============================================================
// lib/src/ui/dashboard/widget_photo_map.dart
// 离线中国地图 - 显示照片拍摄地点分布
// 使用 CustomPainter 绘制，完全离线可用
// ============================================================
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import '../../db/database.dart';
import '../../providers/provider_app.dart';
import '../../providers/provider_database.dart';
import '../browser/page_browser.dart';

/// 照片地图组件
/// 显示中国地图，在城市位置上标记照片数量
class PhotoMapWidget extends ConsumerStatefulWidget {
  const PhotoMapWidget({super.key});

  @override
  ConsumerState<PhotoMapWidget> createState() => _PhotoMapWidgetState();
}

class _PhotoMapWidgetState extends ConsumerState<PhotoMapWidget> {
  // 地图数据
  Map<String, int> _cityData = {};
  Map<String, List<double>> _cityCenters = {};
  List<_ProvinceData> _provinces = [];
  bool _loading = true;
  String? _error;

  // 交互状态
  double _scale = 3.0; // 默认 3 倍缩放，聚焦江苏省
  double _minScale = 1.0;
  double _maxScale = 8.0;
  Offset _offset = Offset.zero;
  Offset? _lastFocalPoint;
  bool _isInitialOffsetSet = false;

  // 地图拟合变换（保持正确宽高比，居中显示）
  Offset _fitOffset = Offset.zero;
  double _fitScale = 1.0;

  // 江苏中心坐标（用于初始定位）
  static const double _jiangsuLng = 118.762765;
  static const double _jiangsuLat = 32.060875;

  // 选中的城市
  String? _selectedCity;

  // 屏幕尺寸
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final db = ref.read(databaseProvider);

      // 1. 读取省份数据
      final jsonStr = await rootBundle.loadString('assets/data/china_regions.json');
      final jsonData = jsonDecode(jsonStr) as Map<String, dynamic>;
      final provinces = (jsonData['province'] as List).map((p) {
        return _ProvinceData.fromJson(p as Map<String, dynamic>);
      }).toList();

      // 2. 读取城市分布数据
      final cityDist = await db.getCityDistribution();

      // 3. 一次查询获取所有城市的中心坐标
      final exifRows = await (db.select(db.exifDatas)
            ..where((e) => e.cityName.isNotNull())
            ..where((e) => e.latitude.isNotNull())
            ..where((e) => e.longitude.isNotNull()))
          .get();

      // 按城市名分组，取第一个坐标作为城市中心
      final cityCenters = <String, List<double>>{};
      for (final exif in exifRows) {
        final city = exif.cityName;
        if (city != null && !cityCenters.containsKey(city)) {
          cityCenters[city] = [exif.longitude!, exif.latitude!];
        }
      }

      setState(() {
        _provinces = provinces;
        _cityData = cityDist;
        _cityCenters = cityCenters;
        _loading = false;
      });
    } catch (e, st) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.focalPoint;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      if (details.pointerCount == 1 && _lastFocalPoint != null) {
        _offset += details.focalPoint - _lastFocalPoint!;
        _lastFocalPoint = details.focalPoint;
      } else if (details.pointerCount >= 2) {
        _scale = (_scale * details.scale).clamp(_minScale, _maxScale);
      }
    });
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    _lastFocalPoint = null;
  }

  /// 以 focalPoint 为中心进行缩放，保持该点不偏移
  void _zoomAt(double factor, Offset focalPoint) {
    final oldScale = _scale;
    final newScale = (_scale * factor).clamp(_minScale, _maxScale);
    final actualFactor = newScale / oldScale;
    if (actualFactor == 1.0) return;
    setState(() {
      _scale = newScale;
      _offset = Offset(
        focalPoint.dx - (focalPoint.dx - _offset.dx) * actualFactor,
        focalPoint.dy - (focalPoint.dy - _offset.dy) * actualFactor,
      );
    });
  }

  void _handleTapDown(TapDownDetails details) {
    if (_cityCenters.isEmpty || _size == Size.zero) return;

    final tapPos = details.localPosition;
    String? tappedCity;

    // 检查点击了哪个城市标记
    for (final entry in _cityCenters.entries) {
      final city = entry.key;
      final center = entry.value;
      final markerPos = _geoToPixel(center[0], center[1]);
      final dist = (tapPos - markerPos).distance;
      final markerRadius = _getMarkerRadius(city);
      if (dist < markerRadius + 10) {
        tappedCity = city;
        break;
      }
    }

    setState(() {
      _selectedCity = tappedCity;
    });
  }

  Offset _geoToPixel(double lng, double lat) {
    // 1. 数据空间坐标
    final dx = lng - _ProvinceData.minLng;
    final dy = _ProvinceData.maxLat - lat;
    // 2. 拟合变换 → 中间坐标
    final fx = dx * _fitScale + _fitOffset.dx;
    final fy = dy * _fitScale + _fitOffset.dy;
    // 3. 用户缩放/平移（与 painter 变换链一致）
    return Offset(fx * _scale + _offset.dx, fy * _scale + _offset.dy);
  }

  double _getMarkerRadius(String city) {
    if (_cityData.isEmpty) return 6.0;
    final count = _cityData[city] ?? 0;
    final maxCount = _cityData.values.reduce(math.max);
    final normalizedSize = (count / maxCount).clamp(0.1, 1.0);
    // 数据空间半径（单位：经纬度度），经 fit + zoom 变换到屏幕空间
    // 3x 聚焦江苏时 fitScale≈10，0.15 度 → 4.5px，0.35 度 → 10.5px
    final dataRadius = 0.15 + normalizedSize * 0.2;
    return dataRadius * _fitScale * _scale;
  }

  // ── 数据空间坐标（供初始定位使用）──
  double _lngToData(double lng) => lng - _ProvinceData.minLng;
  double _latToData(double lat) => _ProvinceData.maxLat - lat;

  // ── 罗盘指示器 ──
  Widget _buildCompass() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.85),
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: const Center(
        child: Text('N', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4A90D9))),
      ),
    );
  }

  // ── 缩放控件 ──
  Widget _buildZoomControls() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF2A2D3E) : Colors.white;
    final iconColor = isDark ? Colors.white70 : const Color(0xFF555555);

    return Container(
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _zoomIcon(Icons.add, () => _zoomAt(1.3, Offset(_size.width / 2, _size.height / 2)), iconColor),
          Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 6), color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08)),
          Text('${(_scale * 100).toInt()}%', style: TextStyle(fontSize: 10, color: iconColor, fontWeight: FontWeight.w500)),
          Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 6), color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08)),
          _zoomIcon(Icons.remove, () => _zoomAt(1 / 1.3, Offset(_size.width / 2, _size.height / 2)), iconColor),
          Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 6), color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08)),
          _zoomIcon(Icons.my_location, () {
            setState(() {
              _scale = 3.0;
              final jx = _lngToData(_jiangsuLng) * _fitScale + _fitOffset.dx;
              final jy = _latToData(_jiangsuLat) * _fitScale + _fitOffset.dy;
              _offset = Offset(_size.width / 2 - jx * _scale, _size.height / 2 - jy * _scale);
            });
          }, iconColor),
        ],
      ),
    );
  }

  Widget _zoomIcon(IconData icon, VoidCallback onTap, Color color) {
    return SizedBox(
      width: 36,
      height: 30,
      child: IconButton(icon: Icon(icon, size: 16, color: color), padding: EdgeInsets.zero, onPressed: onTap),
    );
  }

  void _navigateToCityFilter() {
    if (_selectedCity == null) return;
    // 设置城市筛选条件
    final currentFilters = ref.read(searchFiltersProvider);
    ref.read(searchFiltersProvider.notifier).state = 
        currentFilters.copyWith(cities: {_selectedCity!});
    // 切换到浏览器页面（时间轴模式，显示所有媒体）
    ref.read(browserModeProvider.notifier).state = BrowserMode.timeline;
    ref.read(currentPageProvider.notifier).state = 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('加载失败: $_error'));
    }
    if (_cityData.isEmpty) {
      return const Center(child: Text('暂无 GPS 城市数据'));
    }

    return Column(
      children: [
        _buildToolbar(),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _size = Size(constraints.maxWidth, constraints.maxHeight);
              return _buildMap();
            },
          ),
        ),
        if (_selectedCity != null) _buildCityDetail(),
      ],
    );
  }

  Widget _buildToolbar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(Icons.map_outlined, size: 16, color: isDark ? Colors.white54 : const Color(0xFF888888)),
          const SizedBox(width: 6),
          Text(
            '照片地理分布',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : const Color(0xFF333333),
            ),
          ),
          const Spacer(),
          // 底部图例
          _LegendDot(color: const Color(0xFF4A90D9), label: '有照片'),
          const SizedBox(width: 12),
          _LegendDot(color: Colors.orange, label: '已选中'),
        ],
      ),
    );
  }

  Widget _buildMap() {
    // 首次渲染时计算拟合变换（保持地图正确宽高比）
    if (!_isInitialOffsetSet && _size.width > 0 && _size.height > 0) {
      _isInitialOffsetSet = true;

      // 计算拟合变换：让地图在 widget 内居中且不变形
      final dataW = _ProvinceData.maxLng - _ProvinceData.minLng; // 62
      final dataH = _ProvinceData.maxLat - _ProvinceData.minLat; // 35
      final dataRatio = dataW / dataH; // ~1.77
      final widgetRatio = _size.width / _size.height;

      if (widgetRatio > dataRatio) {
        // widget 更宽 → 按高度限制
        _fitScale = _size.height / dataH;
        _fitOffset = Offset((_size.width - dataW * _fitScale) / 2, 0);
      } else {
        // widget 更高 → 按宽度限制
        _fitScale = _size.width / dataW;
        _fitOffset = Offset(0, (_size.height - dataH * _fitScale) / 2);
      }

      // 计算聚焦江苏的偏移量
      final jx = _lngToData(_jiangsuLng) * _fitScale + _fitOffset.dx;
      final jy = _latToData(_jiangsuLat) * _fitScale + _fitOffset.dy;
      _offset = Offset(_size.width / 2 - jx * _scale, _size.height / 2 - jy * _scale);
    }

    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          _zoomAt(
            event.scrollDelta.dy < 0 ? 1.15 : 1 / 1.15,
            event.localPosition,
          );
        }
      },
      child: GestureDetector(
        onScaleStart: _handleScaleStart,
        onScaleUpdate: _handleScaleUpdate,
        onScaleEnd: _handleScaleEnd,
        onTapDown: _handleTapDown,
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                CustomPaint(
                  size: Size.infinite,
                  painter: _ChinaMapPainter(
                    provinces: _provinces,
                    cityData: _cityData,
                    cityCenters: _cityCenters,
                    scale: _scale,
                    offset: _offset,
                    fitOffset: _fitOffset,
                    fitScale: _fitScale,
                    selectedCity: _selectedCity,
                    isDark: Theme.of(context).brightness == Brightness.dark,
                  ),
                ),
                Positioned(left: 12, top: 12, child: _buildCompass()),
                Positioned(right: 8, top: 8, child: _buildZoomControls()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCityDetail() {
    final city = _selectedCity!;
    final count = _cityData[city] ?? 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2D3E).withOpacity(0.6) : const Color(0xFFF0F4FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Color(0xFF4A90D9),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(city,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isDark ? Colors.white : const Color(0xFF333333),
                    )),
                Text('$count 张照片',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : const Color(0xFF888888),
                    )),
              ],
            ),
          ),
          Material(
            color: const Color(0xFF4A90D9),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _navigateToCityFilter,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                child: Text('查看照片',
                    style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 图例圆点
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : const Color(0xFF888888))),
      ],
    );
  }
}

/// 省份数据
class _ProvinceData {
  // 中国地图边界（经纬度范围）
  static const double minLng = 73.0;
  static const double maxLng = 135.0;
  static const double minLat = 18.0;
  static const double maxLat = 53.0;

  final String name;
  final String adcode;
  final List<double> center;
  final List<List<double>> polygon;

  _ProvinceData({
    required this.name,
    required this.adcode,
    required this.center,
    required this.polygon,
  });

  factory _ProvinceData.fromJson(Map<String, dynamic> json) {
    return _ProvinceData(
      name: json['name'] as String,
      adcode: json['adcode'] as String,
      center: (json['center'] as List).map((e) => e as double).toList(),
      polygon: (json['polygon'] as List)
          .map((p) => (p as List).map((e) => e as double).toList())
          .toList(),
    );
  }
}

/// 中国地图绘制器
class _ChinaMapPainter extends CustomPainter {
  final List<_ProvinceData> provinces;
  final Map<String, int> cityData;
  final Map<String, List<double>> cityCenters;
  final double scale;
  final Offset offset;
  final Offset fitOffset;
  final double fitScale;
  final String? selectedCity;
  final bool isDark;

  _ChinaMapPainter({
    required this.provinces,
    required this.cityData,
    required this.cityCenters,
    required this.scale,
    required this.offset,
    required this.fitOffset,
    required this.fitScale,
    required this.selectedCity,
    required this.isDark,
  });

  Color _bgColor() => isDark ? const Color(0xFF1A1B2E) : const Color(0xFFE8EEF4);
  Color _provinceFill() => isDark ? const Color(0xFF2A2D3E) : const Color(0xFFF2F4F7);
  Color _provinceStroke() => isDark ? const Color(0xFF3A3D4E) : const Color(0xFFC8D0D8);
  Color _markerDefault() => const Color(0xFF4A90D9);
  Color _markerSelected() => const Color(0xFFFF8C42);

  // 数据空间坐标：lng → x = lng - minLng,  lat → y = maxLat - lat
  double _lngToX(double lng) => lng - _ProvinceData.minLng;
  double _latToY(double lat) => _ProvinceData.maxLat - lat;

  @override
  void paint(Canvas canvas, Size size) {
    // 背景填满整个 widget
    final bgPaint = Paint()..color = _bgColor();
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 变换链：数据空间 → fit 变换 → 用户缩放/平移 → 屏幕
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale, scale);
    canvas.translate(fitOffset.dx, fitOffset.dy);
    canvas.scale(fitScale, fitScale);

    _drawGrid(canvas);
    _drawProvinceOutlines(canvas);
    _drawCityMarkers(canvas);

    canvas.restore();
  }

  void _drawGrid(Canvas canvas) {
    final gridPaint = Paint()
      ..color = isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.04)
      ..strokeWidth = 0.5 / (fitScale * scale);
    for (int lat = 20; lat <= 50; lat += 5) {
      final y = _latToY(lat.toDouble());
      canvas.drawLine(Offset(0, y), Offset(62.0, y), gridPaint);
    }
    for (int lng = 75; lng <= 130; lng += 5) {
      final x = _lngToX(lng.toDouble());
      canvas.drawLine(Offset(x, 0), Offset(x, 35.0), gridPaint);
    }
  }

  void _drawProvinceOutlines(Canvas canvas) {
    final fillPaint = Paint()
      ..color = _provinceFill()
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = _provinceStroke()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8 / (fitScale * scale);

    for (final province in provinces) {
      if (province.polygon.isEmpty) continue;
      final path = Path();
      final first = province.polygon.first;
      path.moveTo(_lngToX(first[0]), _latToY(first[1]));
      for (int i = 1; i < province.polygon.length; i++) {
        final point = province.polygon[i];
        path.lineTo(_lngToX(point[0]), _latToY(point[1]));
      }
      path.close();
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, borderPaint);
    }
  }

  void _drawCityMarkers(Canvas canvas) {
    if (cityData.isEmpty) return;
    final maxCount = cityData.values.reduce(math.max);

    for (final entry in cityData.entries) {
      final city = entry.key;
      final count = entry.value;
      final center = cityCenters[city];
      if (center == null) continue;

      final x = _lngToX(center[0]);
      final y = _latToY(center[1]);
      final normalizedSize = (count / maxCount).clamp(0.1, 1.0);
      final baseRadius = 0.15 + normalizedSize * 0.2;
      final isSelected = city == selectedCity;
      final mainColor = isSelected ? _markerSelected() : _markerDefault();

      // 简洁标记：纯色圆 + 白色描边
      canvas.drawCircle(Offset(x, y), baseRadius, Paint()
        ..color = mainColor);
      canvas.drawCircle(Offset(x, y), baseRadius, Paint()
        ..color = Colors.white.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 / (fitScale * scale));

      if (isSelected || scale > 2.5) {
        final fontSize = (isSelected ? 11.0 : 10.0) / (fitScale * scale);
        final tp = TextPainter(
          text: TextSpan(
            text: isSelected ? '$city  $count张' : city,
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF333333),
              fontSize: fontSize, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal),
          ),
          textDirection: ui.TextDirection.ltr, textAlign: TextAlign.center,
        );
        tp.layout();
        tp.paint(canvas, Offset(x - tp.width / 2, y + baseRadius + 2.0 / (fitScale * scale)));
      }
    }
  }

  @override
  bool shouldRepaint(_ChinaMapPainter oldDelegate) {
    return oldDelegate.scale != scale || oldDelegate.offset != offset ||
        oldDelegate.selectedCity != selectedCity || oldDelegate.cityData != cityData ||
        oldDelegate.fitScale != fitScale;
  }
}
