// ============================================================
// lib/src/providers/provider_app.dart
// 跨页面的共享状态：标签、媒体标签关联
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database.dart';
import 'provider_database.dart';

/// 所有标签（用于任意位置弹出标签列表）
final allTagsProvider = FutureProvider<List<Tag>>((ref) {
  return ref.read(databaseProvider).getAllTags();
});

/// 媒体项已有的标签 id 集合（按 mediaId 缓存）
final mediaTagsProvider =
    FutureProvider.family<List<Tag>, int>((ref, mediaId) async {
  final db = ref.read(databaseProvider);
  final rows = await (db.select(db.mediaTags)
        ..where((mt) => mt.mediaItemId.equals(mediaId)))
      .get();
  if (rows.isEmpty) return [];
  final tagIds = rows.map((r) => r.tagId).toList();
  return (db.select(db.tags)..where((t) => t.id.isIn(tagIds))).get();
});

/// 浏览器扫描/编辑后通知其他页面刷新。
/// 每次自增一下，dashboard / exif 页用 ref.listen 监听。
final browserRefreshSignalProvider = StateProvider<int>((ref) => 0);

// ─────────────────────────────────────────────
// 时间轴联动状态
// ─────────────────────────────────────────────

/// 时间轴当前激活的桶（"YYYY-MM"），由图片网格滚动时更新。
final activeTimelineBucketProvider = StateProvider<String?>((ref) => null);

/// 时间轴联动的"通讯"状态：
/// - scrollController: 媒体网格的滚动控制器（由网格 widget 注册）
/// - bucketKeys: 每个桶第一个 item 的 GlobalKey（用于 Scrollable.ensureVisible 跳转）
/// - bucketFirstIndex: 每个桶第一个 item 在 sorted 列表中的全局下标（用于在 key
///   还未注册时估算 offset，强制 GridView build 该区域后再精确跳）
class TimelineLinkState {
  final ScrollController? scrollController;
  final Map<String, GlobalKey> bucketKeys;
  final Map<String, int> bucketFirstIndex;
  final int totalItemCount;
  const TimelineLinkState({
    this.scrollController,
    this.bucketKeys = const {},
    this.bucketFirstIndex = const {},
    this.totalItemCount = 0,
  });

  TimelineLinkState copyWith({
    ScrollController? scrollController,
    Map<String, GlobalKey>? bucketKeys,
    Map<String, int>? bucketFirstIndex,
    int? totalItemCount,
    bool clearScroll = false,
  }) {
    return TimelineLinkState(
      scrollController:
          clearScroll ? null : (scrollController ?? this.scrollController),
      bucketKeys: bucketKeys ?? this.bucketKeys,
      bucketFirstIndex: bucketFirstIndex ?? this.bucketFirstIndex,
      totalItemCount: totalItemCount ?? this.totalItemCount,
    );
  }
}

class TimelineLinkNotifier extends StateNotifier<TimelineLinkState> {
  TimelineLinkNotifier() : super(const TimelineLinkState());

  void attachScroll(ScrollController c) {
    if (state.scrollController == c) return;
    state = state.copyWith(scrollController: c);
  }

  void detachScroll(ScrollController c) {
    if (state.scrollController == c) {
      state = state.copyWith(clearScroll: true);
    }
  }

  /// 注册/刷新桶的首项 key；同一个桶只保留第一个 key。
  void registerBucketKey(String bucket, GlobalKey key) {
    if (state.bucketKeys[bucket] == key) return;
    final next = Map<String, GlobalKey>.from(state.bucketKeys);
    next[bucket] = key;
    state = state.copyWith(bucketKeys: next);
  }

  void clearBucketKeys() {
    if (state.bucketKeys.isEmpty &&
        state.bucketFirstIndex.isEmpty &&
        state.totalItemCount == 0) {
      return;
    }
    state = state.copyWith(
      bucketKeys: const {},
      bucketFirstIndex: const {},
      totalItemCount: 0,
    );
  }

  /// 注册"桶 → 首项 index"以及总数（不依赖 widget build，纯数据）。
  /// 用于点击右侧时间时：远端 bucket key 还没注册，可以先估算 offset
  /// 强制 GridView 把目标区域 build 出来，build 完后再精确 ensureVisible。
  void setBucketLayout({
    required Map<String, int> bucketFirstIndex,
    required int totalItemCount,
  }) {
    state = state.copyWith(
      bucketFirstIndex: bucketFirstIndex,
      totalItemCount: totalItemCount,
    );
  }
}

final timelineLinkProvider =
    StateNotifierProvider<TimelineLinkNotifier, TimelineLinkState>(
        (ref) => TimelineLinkNotifier());

/// 时间轴侧边栏桶数据（按月聚合，来自 MediaDateIndexes 表）
/// 不依赖于 browserMediaProvider，避免全量加载所有媒体项
/// 监听 browserRefreshSignalProvider，扫描/导入/删除后自动刷新
final timelineBucketsProvider = FutureProvider<List<MonthlyBucket>>((ref) {
  // 监听刷新信号：每次信号自增时，此 provider 自动失效并重载
  ref.watch(browserRefreshSignalProvider);
  return ref.read(databaseProvider).getMonthlyDateBuckets();
});

/// EXIF 城市筛选条件（由地图页设置，浏览器页监听）
final exifCityFilterProvider = StateProvider<String?>((ref) => null);

/// 当前页面索引（0=浏览器，1=仪表盘）
final currentPageProvider = StateProvider<int>((ref) => 0);
