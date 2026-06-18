// ============================================================
// lib/src/ui/dashboard/page_dashboard.dart
// 仪表盘：大文件占比 + 城市分布 + 标签词云
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:drift/drift.dart' show innerJoin;
import '../../db/database.dart';
import '../../providers/provider_database.dart';
import '../../providers/provider_app.dart';
import '../widgets/dialog_manual_viewer.dart';

// ── Providers ──

final fileSizeBucketsProvider = FutureProvider<List<FileSizeBucket>>((ref) {
  return ref.read(databaseProvider).getFileSizeBuckets();
});

final cityDistributionProvider = FutureProvider<Map<String, int>>((ref) {
  return ref.read(databaseProvider).getCityDistribution();
});

final tagCloudProvider = FutureProvider<List<TagCloudItem>>((ref) {
  return ref.read(databaseProvider).getTagCloud();
});

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final db = ref.read(databaseProvider);
  // 只统计未软删的媒体
  final alive =
      (db.select(db.mediaItems)..where((t) => t.isDeleted.equals(false)));
  final total = await alive.get().then((r) => r.length);
  // 含 EXIF 数量：关联到未软删的媒体
  final exifRows = await (db.select(db.exifDatas).join([
    innerJoin(
      db.mediaItems,
      db.mediaItems.id.equalsExp(db.exifDatas.mediaItemId),
    )
  ])
        ..where(db.mediaItems.isDeleted.equals(false)))
      .get();
  final withExif = exifRows.length;
  final tags = await db.getAllTags().then((r) => r.length);
  // 总占用空间只累加未软删的文件
  final totalSize = (await alive.get())
      .fold<int>(0, (sum, i) => sum + (i.fileSizeBytes ?? 0));
  return DashboardStats(
    totalMedia: total,
    withExif: withExif,
    tagCount: tags,
    totalSizeBytes: totalSize,
  );
});

class DashboardStats {
  final int totalMedia;
  final int withExif;
  final int tagCount;
  final int totalSizeBytes;
  const DashboardStats({
    required this.totalMedia,
    required this.withExif,
    required this.tagCount,
    required this.totalSizeBytes,
  });
}

// ── 页面 ──

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    ref.watch(fileSizeBucketsProvider);
    ref.watch(cityDistributionProvider);
    ref.watch(tagCloudProvider);

    // 监听浏览器传递的刷新信号
    ref.listen<int>(browserRefreshSignalProvider, (_, __) {
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(fileSizeBucketsProvider);
      ref.invalidate(cityDistributionProvider);
      ref.invalidate(tagCloudProvider);
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: _CapsuleAppBarShell(
            title: '仪表盘',
            actions: [
              _ManualButton(),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            // 顶部统计卡片
            statsAsync.when(
              loading: () => const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Text('$e'),
              data: (stats) => _StatsRow(stats: stats),
            ),
            const SizedBox(height: 24),

            // 图表区（三列布局）
            LayoutBuilder(builder: (ctx, constraints) {
              final wide = constraints.maxWidth > 900;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _FileSizePieCard()),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: _CityBarCard()),
                  ],
                );
              } else {
                return Column(children: [
                  _FileSizePieCard(),
                  const SizedBox(height: 16),
                  _CityBarCard(),
                ]);
              }
            }),
            const SizedBox(height: 24),

            // 标签词云
            _TagCloudCard(),
          ],
        ),
      ),
    );
  }
}

// ── 统计卡片行 ──

class _StatsRow extends StatelessWidget {
  final DashboardStats stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final totalMB = (stats.totalSizeBytes / 1024 / 1024).toStringAsFixed(0);
    final totalGB =
        (stats.totalSizeBytes / 1024 / 1024 / 1024).toStringAsFixed(2);
    final sizeLabel = stats.totalSizeBytes > 1024 * 1024 * 1024
        ? '$totalGB GB'
        : '$totalMB MB';

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _StatCard(
          label: '媒体总数',
          value: '${stats.totalMedia}',
          icon: Icons.photo_library,
          color: Colors.blue,
        ),
        _StatCard(
          label: '含 EXIF',
          value: '${stats.withExif}',
          icon: Icons.info_outline,
          color: Colors.teal,
        ),
        _StatCard(
          label: '标签数量',
          value: '${stats.tagCount}',
          icon: Icons.label,
          color: Colors.orange,
        ),
        _StatCard(
          label: '总占用空间',
          value: sizeLabel,
          icon: Icons.storage,
          color: Colors.purple,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E1F2D).withOpacity(0.85)
            : Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        )),
                Text(label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? const Color(0xFF9CA3AF)
                              : const Color(0xFF6B7280),
                        )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── 文件大小饼图 ──

class _FileSizePieCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bucketsAsync = ref.watch(fileSizeBucketsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E1F2D).withOpacity(0.85)
            : Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('文件大小分布',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
            const SizedBox(height: 16),
            bucketsAsync.when(
              loading: () => const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Text('$e'),
              data: (buckets) => _PieChart(buckets: buckets),
            ),
          ],
        ),
      ),
    );
  }
}

class _PieChart extends StatefulWidget {
  final List<FileSizeBucket> buckets;
  const _PieChart({required this.buckets});

  @override
  State<_PieChart> createState() => _PieChartState();
}

class _PieChartState extends State<_PieChart> {
  int _touchedIndex = -1;

  static const _colors = [
    Color(0xFF378ADD),
    Color(0xFF2ECC71),
    Color(0xFFF39C12),
    Color(0xFFE74C3C),
    Color(0xFF9B59B6),
  ];

  @override
  Widget build(BuildContext context) {
    final total = widget.buckets.fold<int>(0, (s, b) => s + b.count);
    if (total == 0) {
      return const SizedBox(height: 200, child: Center(child: Text('暂无数据')));
    }

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (evt, resp) {
                  setState(() {
                    if (!evt.isInterestedForInteractions ||
                        resp?.touchedSection == null) {
                      _touchedIndex = -1;
                    } else {
                      _touchedIndex = resp!.touchedSection!.touchedSectionIndex;
                    }
                  });
                },
              ),
              sections: List.generate(widget.buckets.length, (i) {
                final b = widget.buckets[i];
                final pct = b.count / total * 100;
                final isTouched = i == _touchedIndex;
                return PieChartSectionData(
                  color: _colors[i % _colors.length],
                  value: b.count.toDouble(),
                  title: '${pct.toStringAsFixed(0)}%',
                  radius: isTouched ? 70 : 56,
                  titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white),
                );
              }),
              centerSpaceRadius: 40,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 图例
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: List.generate(widget.buckets.length, (i) {
            final b = widget.buckets[i];
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _colors[i % _colors.length],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Text('${b.label} (${b.count})',
                    style: const TextStyle(fontSize: 12)),
              ],
            );
          }),
        ),
      ],
    );
  }
}

// ── 城市分布柱状图 ──

class _CityBarCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cityAsync = ref.watch(cityDistributionProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E1F2D).withOpacity(0.85)
            : Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('拍摄城市分布',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
            const SizedBox(height: 16),
            cityAsync.when(
              loading: () => const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Text('$e'),
              data: (cityMap) => _CityBarChart(cityMap: cityMap),
            ),
          ],
        ),
      ),
    );
  }
}

class _CityBarChart extends StatelessWidget {
  final Map<String, int> cityMap;
  const _CityBarChart({required this.cityMap});

  @override
  Widget build(BuildContext context) {
    if (cityMap.isEmpty) {
      return const SizedBox(
          height: 200, child: Center(child: Text('暂无 GPS 城市数据')));
    }

    // 取前 10 城市
    final sorted = cityMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(10).toList();
    final maxVal = top.first.value.toDouble();

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxVal * 1.2,
          barGroups: List.generate(top.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: top[i].value.toDouble(),
                  color: const Color(0xFF378ADD),
                  width: 20,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}',
                        style: const TextStyle(fontSize: 10),
                      )),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (v, meta) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= top.length) {
                    return const SizedBox();
                  }
                  // 显示城市名（截断）
                  final city = top[idx].key;
                  final short =
                      city.length > 6 ? '${city.substring(0, 5)}…' : city;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(short, style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${top[group.x].key}\n${rod.toY.toInt()} 张',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ── 标签词云 ──

class _TagCloudCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagCloudProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E1F2D).withOpacity(0.85)
            : Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('标签',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
            const SizedBox(height: 16),
            tagsAsync.when(
              loading: () => const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Text('$e'),
              data: (items) => _TagWordCloud(items: items),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagWordCloud extends StatelessWidget {
  final List<TagCloudItem> items;
  const _TagWordCloud({required this.items});

  @override
  Widget build(BuildContext context) {
    final sorted = [...items]..sort((a, b) => b.count.compareTo(a.count));

    if (sorted.isEmpty || sorted.every((i) => i.count == 0)) {
      return const Center(child: Text('暂无标签数据'));
    }

    final maxCount = sorted.first.count;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: sorted.where((i) => i.count > 0).map((item) {
        final ratio = maxCount > 0 ? item.count / maxCount : 0.5;
        final fontSize = 12.0 + ratio * 20;
        final color =
            Color(int.parse(item.tag.color.replaceFirst('#', '0xFF')));

        return GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${item.tag.name}: ${item.count} 张'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              item.tag.name,
              style: TextStyle(
                fontSize: fontSize,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CapsuleAppBarShell extends StatelessWidget {
  final String title;
  final List<Widget> actions;
  const _CapsuleAppBarShell({required this.title, this.actions = const []});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E1F2D).withOpacity(0.9)
            : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                )),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// 顶部「使用手册」按钮
class _ManualButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '查看使用手册',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => ManualViewerDialog.show(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF5B8DEF), Color(0xFF7B5BEF)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5B8DEF).withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.menu_book_rounded, color: Colors.white, size: 16),
              SizedBox(width: 6),
              Text('使用手册',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
