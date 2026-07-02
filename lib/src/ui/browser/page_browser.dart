// ============================================================
// lib/src/ui/browser/page_browser.dart
// 主浏览器页面：
// - 从数据库加载（不再绑死某个文件夹）
// - 三种视图：时间轴 / 文件夹 / 标签
// - 缺省文件显示 ⚠️ 角标
// - 单击详情 / 长按多选 / 右键菜单（仅 详情 / 编辑标签 / 删除）
// - 删除 = 软删除（DB 标记 isDeleted=true）
// - 顶部按钮：导入文件夹、整库对账、单文件导入
// ============================================================
import 'dart:io';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:path/path.dart' as p;
import '../../db/database.dart';
import '../../providers/provider_database.dart';
import '../../providers/provider_app.dart';
import '../../services/service_media_scanner.dart';
import '../../services/helper_md5.dart' as Md5Service;
import '../../services/service_scan_controller.dart';
import 'widget_media_grid_item.dart';
import 'widget_pixel_thumb.dart';
import 'widget_scan_progress.dart';
import 'dialog_scan_config.dart';
import 'view_video_player.dart';
import '../tags/dialog_tag_editor.dart';
import '../widgets/view_full_screen_image.dart';

// ─────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────

/// 浏览器视图模式
enum BrowserMode { timeline, folder, tag }

/// 单项 / 列表 / 网格 / 时间轴侧栏
enum ViewMode { large, medium, list }

/// 顶部排序按钮：时间 / 大小 / 文件名 × 升降序
///
/// 字段顺序按"维度分组、组内按降序在前"：timeDesc → timeAsc → sizeDesc → sizeAsc → nameDesc → nameAsc。
/// 默认 `timeDesc`（最新 → 最旧，与时间轴一致）。
enum BrowserSort {
  timeDesc,
  timeAsc,
  sizeDesc,
  sizeAsc,
  nameDesc,
  nameAsc,
}

final browserSortProvider =
    StateProvider<BrowserSort>((_) => BrowserSort.timeDesc);

final browserModeProvider =
    StateProvider<BrowserMode>((_) => BrowserMode.timeline);
final viewModeProvider = StateProvider<ViewMode>((_) => ViewMode.medium);
final currentFolderProvider = StateProvider<String?>((_) => null);
final currentTagFilterProvider = StateProvider<int?>((_) => null);

/// 浏览器顶部文件名搜索（空串 = 不过滤）
final filenameSearchProvider = StateProvider<String>((_) => '');

/// 搜索条件聚合：文件名 + 设备 + 城市 + 拍摄时间 + 标签（多选）
class SearchFilters {
  final String filename;
  final Set<String> cameras; // "Make Model" 字符串
  final Set<String> cities; // cityName
  final DateTimeRange? dateRange;
  final Set<int> tagIds; // 任一命中即通过（OR）
  final String? fileType; // null=全部, 'image'=仅图片, 'video'=仅视频

  const SearchFilters({
    this.filename = '',
    this.cameras = const {},
    this.cities = const {},
    this.dateRange,
    this.tagIds = const {},
    this.fileType,
  });

  bool get isEmpty =>
      filename.isEmpty &&
      cameras.isEmpty &&
      cities.isEmpty &&
      dateRange == null &&
      tagIds.isEmpty &&
      fileType == null;

  /// 不含文件名的活跃条件数（用于过滤按钮角标）
  int get activeExtras =>
      (cameras.isNotEmpty ? 1 : 0) +
      (cities.isNotEmpty ? 1 : 0) +
      (dateRange != null ? 1 : 0) +
      (tagIds.isNotEmpty ? 1 : 0) +
      (fileType != null ? 1 : 0);

  SearchFilters copyWith({
    String? filename,
    Set<String>? cameras,
    Set<String>? cities,
    DateTimeRange? dateRange,
    bool clearDateRange = false,
    Set<int>? tagIds,
    String? fileType,
    bool clearFileType = false,
  }) {
    return SearchFilters(
      filename: filename ?? this.filename,
      cameras: cameras ?? this.cameras,
      cities: cities ?? this.cities,
      dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
      tagIds: tagIds ?? this.tagIds,
      fileType: clearFileType ? null : (fileType ?? this.fileType),
    );
  }
}

final searchFiltersProvider =
    StateProvider<SearchFilters>((_) => const SearchFilters());

/// EXIF 中出现过的设备列表（去重，"Make Model"）
final distinctCamerasProvider = FutureProvider<List<String>>((ref) async {
  ref.watch(browserRefreshSignalProvider);
  final db = ref.read(databaseProvider);
  final rows = await db.select(db.exifDatas).get();
  final set = <String>{};
  for (final r in rows) {
    final s = '${r.make ?? ''} ${r.model ?? ''}'.trim();
    if (s.isNotEmpty) set.add(s);
  }
  final list = set.toList()..sort();
  return list;
});

/// EXIF 中出现过的城市列表（去重）
final distinctCitiesProvider = FutureProvider<List<String>>((ref) async {
  ref.watch(browserRefreshSignalProvider);
  final db = ref.read(databaseProvider);
  final rows = await (db.select(db.exifDatas)
        ..where((t) => t.cityName.isNotNull()))
      .get();
  final set = <String>{};
  for (final r in rows) {
    final c = r.cityName;
    if (c != null && c.isNotEmpty) set.add(c);
  }
  final list = set.toList()..sort();
  return list;
});

/// 主列表（按 mode + filter 排序派生）
///
/// 流程：取数 → 5 项搜索条件过滤 → 排序（默认按创建时间降序，与时间轴一致）。
/// 把排序也放在这一个 provider 内：UI 端不需要换 provider；切换排序时
/// Riverpod 不会重跑数据库查询，因为 db.getAllMedia() 的结果已 cache 在
/// db 内层 provider 里（只有 invalidate 才重跑）。
final browserMediaProvider =
    FutureProvider<List<MediaItemWithMeta>>((ref) async {
  final db = ref.read(databaseProvider);
  final mode = ref.watch(browserModeProvider);
  final folder = ref.watch(currentFolderProvider);
  final tagId = ref.watch(currentTagFilterProvider);
  final sort = ref.watch(browserSortProvider);
  // 监听刷新信号
  ref.watch(browserRefreshSignalProvider);

  final raw = await () async {
    switch (mode) {
      case BrowserMode.timeline:
        return db.getAllMedia();
      case BrowserMode.folder:
        if (folder == null) return <MediaItemWithMeta>[];
        return db.getDirectMediaInFolder(folder);
      case BrowserMode.tag:
        if (tagId == null) return <MediaItemWithMeta>[];
        final items = await db.getItemsByTag(tagId);
        return Future.wait(items.map((it) async {
          final exif = await (db.select(db.exifDatas)
                ..where((e) => e.mediaItemId.equals(it.id)))
              .getSingleOrNull();
          final tagIdList = await (db.select(db.mediaTags)
                ..where((mt) => mt.mediaItemId.equals(it.id)))
              .get()
              .then((r) => r.map((x) => x.tagId).toList());
          final tags = tagIdList.isEmpty
              ? <Tag>[]
              : await (db.select(db.tags)..where((t) => t.id.isIn(tagIdList)))
                  .get();
          return MediaItemWithMeta(item: it, exif: exif, tags: tags,
              videoMeta: await db.getVideoMeta(it.id));
        }));
    }
  }();

  // 6 项搜索条件（文件名 / 设备 / 城市 / 拍摄时间 / 标签 / 媒体类型）
  final filters = ref.watch(searchFiltersProvider);
  final filtered = filters.isEmpty
      ? raw
      : raw.where((m) {
          final lower = filters.filename.toLowerCase();
          // 1) 文件名
          if (lower.isNotEmpty &&
              !m.item.fileName.toLowerCase().contains(lower)) {
            return false;
          }
          // 2) 设备（make+model 子串匹配，忽略大小写）
          if (filters.cameras.isNotEmpty) {
            final cam = '${m.exif?.make ?? ''} ${m.exif?.model ?? ''}'.trim();
            final camLower = cam.toLowerCase();
            final hit =
                filters.cameras.any((c) => camLower.contains(c.toLowerCase()));
            if (!hit) return false;
          }
          // 3) 城市（精确匹配 cityName 之一）
          if (filters.cities.isNotEmpty) {
            final c = m.exif?.cityName;
            if (c == null || !filters.cities.contains(c)) return false;
          }
          // 4) 拍摄时间（落在区间内）
          if (filters.dateRange != null) {
            final dt = m.exif?.dateTaken;
            if (dt == null) return false;
            // 结束日包含整天：把 end 设为次日 0 点之前
            final end = filters.dateRange!.end
                .add(const Duration(days: 1))
                .subtract(const Duration(milliseconds: 1));
            if (dt.isBefore(filters.dateRange!.start) || dt.isAfter(end)) {
              return false;
            }
          }
          // 5) 标签（命中任一即通过，OR）
          if (filters.tagIds.isNotEmpty) {
            final itemTagIds = m.tags.map((t) => t.id).toSet();
            if (filters.tagIds.intersection(itemTagIds).isEmpty) return false;
          }
          // 6) 媒体类型（image / video）
          if (filters.fileType != null &&
              m.item.fileType != filters.fileType) {
            return false;
          }
          return true;
        }).toList();

  // 排序
  final list = [...filtered];
  // 时间键：EXIF DateTimeOriginal > 磁盘 mtime > 归档时间
  DateTime timeOf(MediaItemWithMeta m) {
    final ex = m.exif?.dateTaken;
    if (ex != null) return ex;
    final mt = m.item.fileModifiedAt;
    if (mt != null) return mt;
    return m.item.indexedAt;
  }

  switch (sort) {
    case BrowserSort.timeDesc:
      list.sort((a, b) => timeOf(b).compareTo(timeOf(a)));
      break;
    case BrowserSort.timeAsc:
      list.sort((a, b) => timeOf(a).compareTo(timeOf(b)));
      break;
    case BrowserSort.sizeDesc:
      // 大小相同时退回到时间降序，避免 order 不稳定
      // fileSizeBytes 可能为 null，null 视为 0
      list.sort((a, b) {
        final aSize = a.item.fileSizeBytes ?? 0;
        final bSize = b.item.fileSizeBytes ?? 0;
        final c = bSize.compareTo(aSize);
        return c != 0 ? c : timeOf(b).compareTo(timeOf(a));
      });
      break;
    case BrowserSort.sizeAsc:
      list.sort((a, b) {
        final aSize = a.item.fileSizeBytes ?? 0;
        final bSize = b.item.fileSizeBytes ?? 0;
        final c = aSize.compareTo(bSize);
        return c != 0 ? c : timeOf(b).compareTo(timeOf(a));
      });
      break;
    case BrowserSort.nameDesc:
      list.sort((a, b) => b.item.fileName
          .toLowerCase()
          .compareTo(a.item.fileName.toLowerCase()));
      break;
    case BrowserSort.nameAsc:
      list.sort((a, b) => a.item.fileName
          .toLowerCase()
          .compareTo(b.item.fileName.toLowerCase()));
      break;
  }
  return list;
});

/// 视图模式 1（folder）：列出已归档的所有文件夹
final folderListProvider = FutureProvider<List<FolderBucket>>((ref) {
  ref.watch(browserRefreshSignalProvider);
  return ref.read(databaseProvider).getAllFolders();
});

/// 文件夹树（层级结构，用于文件夹模式的侧边栏树形视图）
final folderTreeProvider = FutureProvider<FolderTreeNode>((ref) {
  ref.watch(browserRefreshSignalProvider);
  return ref.read(databaseProvider).buildFolderTree();
});

/// 子文件夹列表（当前选中文件夹的直接子目录，用于右侧内容区展示）
final subFoldersProvider = FutureProvider<List<SubFolderEntry>>((ref) {
  final folder = ref.watch(currentFolderProvider);
  ref.watch(browserRefreshSignalProvider);
  if (folder == null) return [];
  return ref.read(databaseProvider).getSubFolders(folder);
});
final scanStateProvider = StateProvider<ScanProgress?>((ref) => null);

final scanControllerProvider = StateProvider<ScanController?>((_) => null);

/// 多选
final selectionProvider = StateProvider<Set<int>?>((ref) => null);

// ── 拖选辅助：用 RenderBox.hitTest 找到鼠标命中的真实 RenderObject，
//    再从 _keyCache 反查对应的 media 项（自动处理 clip/transform/层叠） ──

MediaItemWithMeta? _hitTestMediaItem(
  Offset localPosition,
  RenderBox gridBox,
  List<MediaItemWithMeta> items,
  Map<int, GlobalKey> keyCache,
) {
  if (!gridBox.attached) return null;
  final hitResult = BoxHitTestResult();
  final globalPos = gridBox.localToGlobal(localPosition);
  if (!gridBox.hitTest(hitResult, position: globalPos)) return null;

  // 先把所有 key 的 renderObject 收集成 Set，便于 O(1) 命中判断
  final keyRenders = <RenderObject>{};
  for (final k in keyCache.values) {
    final ro = k.currentContext?.findRenderObject();
    if (ro != null) keyRenders.add(ro);
  }

  // hitTest 的 path 是从外到内，遍历到第一个匹配 key 的 render object
  final path = hitResult.path.toList();
  for (int i = path.length - 1; i >= 0; i--) {
    final ro = path[i].target;
    if (!keyRenders.contains(ro)) continue;
    for (final entry in keyCache.entries) {
      final ctx = entry.value.currentContext;
      if (ctx != null && ctx.findRenderObject() == ro) {
        for (final m in items) {
          if (m.item.id == entry.key) return m;
        }
      }
    }
  }
  return null;
}

// ─────────────────────────────────────────────
// 页面
// ─────────────────────────────────────────────

class BrowserPage extends ConsumerStatefulWidget {
  const BrowserPage({super.key});

  @override
  ConsumerState<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends ConsumerState<BrowserPage> {
  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(browserModeProvider);
    final selection = ref.watch(selectionProvider);
    final inMulti = selection != null;
    final scanState = ref.watch(scanStateProvider);
    final scanController = ref.watch(scanControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: _CapsuleAppBar(
            leading: inMulti
                ? IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: '退出多选',
                    onPressed: () =>
                        ref.read(selectionProvider.notifier).state = null,
                  )
                : null,
            title: inMulti
                ? Text('已选 ${selection.length} 项',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15))
                : _titleForMode(mode),
            actions:
                inMulti ? _buildMultiSelectActions() : _buildNormalActions(),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E1F2D).withOpacity(0.7)
                : Colors.white.withOpacity(0.55),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withOpacity(0.2)
                    : Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _SearchBar(),
              // 非阻塞扫描进度面板
              if (scanState != null && scanController != null)
                ScanProgressPanel(
                  progress: scanState,
                  controller: scanController,
                ),
              Expanded(
                child: Row(
                  children: [
                    SizedBox(width: 220, child: _ModeSidebar()),
                    Container(
                        width: 1,
                        color: Theme.of(context).dividerColor.withOpacity(0.4)),
                    Expanded(child: _buildContent(mode)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _titleForMode(BrowserMode m) {
    final folder = ref.watch(currentFolderProvider);
    final tagId = ref.watch(currentTagFilterProvider);
    const style = TextStyle(fontWeight: FontWeight.w600, fontSize: 15);
    switch (m) {
      case BrowserMode.timeline:
        return const Text('PicGuide · 全部', style: style);
      case BrowserMode.folder:
        return Text(folder != null ? p.basename(folder) : '文件夹', style: style);
      case BrowserMode.tag:
        return Text('标签 #$tagId', style: style);
    }
  }

  List<Widget> _buildNormalActions() {
    final vm = ref.watch(viewModeProvider);
    final sort = ref.watch(browserSortProvider);
    final scanController = ref.watch(scanControllerProvider);
    final isScanning = scanController != null &&
        (scanController.state == ScanState.scanning ||
            scanController.state == ScanState.paused);
    return [
      _ViewModeToggle(
        current: vm,
        onChanged: (v) => ref.read(viewModeProvider.notifier).state = v,
      ),
      const SizedBox(width: 4),
      _SortButton(
        current: sort,
        onChanged: (v) => ref.read(browserSortProvider.notifier).state = v,
      ),
      const SizedBox(width: 8),
      _CapsuleIconAction(
        icon: Icons.create_new_folder_outlined,
        tooltip: '导入文件夹',
        onTap: isScanning ? null : _pickFolder,
        enabled: !isScanning,
      ),
      const SizedBox(width: 4),
      _CapsuleIconAction(
        icon: Icons.add_photo_alternate_outlined,
        tooltip: '导入单文件',
        onTap: isScanning ? null : _pickSingleFile,
        enabled: !isScanning,
      ),
      const SizedBox(width: 4),
      _CapsuleIconAction(
        icon: Icons.fact_check_outlined,
        tooltip: '全库对账（查找缺失文件）',
        onTap: isScanning ? null : _reconcileAll,
        enabled: !isScanning,
      ),
      const SizedBox(width: 4),
      _CapsuleIconAction(
        icon: Icons.location_on_outlined,
        tooltip: '全库重新分析区域（GPS → 省/市）',
        onTap: isScanning ? null : _reAnalyzeRegions,
        enabled: !isScanning,
      ),
      const SizedBox(width: 4),
      _CapsuleIconAction(
        icon: Icons.image_outlined,
        tooltip: '全库缩略图扫描（重新生成缺失缩略图）',
        onTap: isScanning ? null : _regenerateAllThumbnails,
        enabled: !isScanning,
      ),
    ];
  }

  List<Widget> _buildMultiSelectActions() {
    final mediaAsync = ref.watch(browserMediaProvider);
    // 全部可见项（与未软删的总数对齐：当前列表 provider 已过滤 isDeleted）
    final visibleIds = mediaAsync.maybeWhen(
      data: (items) => items.map((m) => m.item.id).toSet(),
      orElse: () => <int>{},
    );
    final selection = ref.watch(selectionProvider) ?? <int>{};
    // 若"可见项都已被选" → 按钮变成"全不选"
    final allSelected =
        visibleIds.isNotEmpty && visibleIds.every(selection.contains);
    return [
      _CapsuleIconAction(
        icon: allSelected ? Icons.deselect : Icons.select_all,
        tooltip: allSelected ? '全不选' : '全选当前列表',
        onTap: () {
          if (allSelected) {
            ref.read(selectionProvider.notifier).state = null;
          } else {
            ref.read(selectionProvider.notifier).state = visibleIds;
          }
        },
      ),
      const SizedBox(width: 4),
      _CapsuleIconAction(
        icon: Icons.label_outline,
        tooltip: '添加标签',
        onTap: _batchAddTags,
      ),
      const SizedBox(width: 4),
      _CapsuleIconAction(
        icon: Icons.delete_outline,
        tooltip: '删除（软删除）',
        color: Colors.red,
        onTap: _batchDelete,
      ),
      const SizedBox(width: 4),
      _CapsuleIconAction(
        icon: Icons.image_outlined,
        tooltip: '重新生成缩略图',
        onTap: _batchRegenerateThumbnails,
      ),
    ];
  }

  Widget _buildContent(BrowserMode mode) {
    final vm = ref.watch(viewModeProvider);
    switch (mode) {
      case BrowserMode.folder:
        final folder = ref.watch(currentFolderProvider);
        if (folder == null) {
          return const Center(child: Text('请选择左侧文件夹'));
        }
        return _MediaContainer(key: ValueKey('folder-$folder-$vm'), mode: vm);
      case BrowserMode.tag:
        final tagId = ref.watch(currentTagFilterProvider);
        if (tagId == null) {
          return const Center(child: Text('请选择左侧标签'));
        }
        return _MediaContainer(key: ValueKey('tag-$tagId-$vm'), mode: vm);
      case BrowserMode.timeline:
        return _MediaContainer(key: ValueKey('timeline-$vm'), mode: vm);
    }
  }

  // ── 顶部按钮回调 ──

  Future<void> _pickFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择图片文件夹',
    );
    if (result != null) {
      // 显示扫描确认弹窗
      final configResult = await ScanConfigDialog.show(context, result);

      if (configResult == null || !configResult.confirmed) {
        return; // 用户取消或关闭了弹窗
      }

      ref.read(currentFolderProvider.notifier).state = result;
      ref.read(browserModeProvider.notifier).state = BrowserMode.folder;
      ref.read(selectionProvider.notifier).state = null;

      await _scanFolder(result);
    }
  }

  Future<void> _pickSingleFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'jpg',
        'jpeg',
        'png',
        'webp',
        'bmp',
        'gif',
        'tiff',
        'heic',
        'heif',
        'mp4',
        'mov',
        'avi',
        'mkv',
        'wmv',
        'flv',
        'webm',
        'm4v',
      ],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    // 重复检测
    final db = ref.read(databaseProvider);
    try {
      final md5h = await _md5OfFile(path);
      final existing = await db.findByMd5(md5h);
      if (existing != null && !existing.isDeleted) {
        if (!mounted) return;
        _showDuplicateDialog(existing);
        return;
      }
    } catch (_) {}

    ref.read(scanStateProvider.notifier).state =
        ScanProgress(current: 0, total: 1, currentFile: p.basename(path));
    try {
      final scanner = MediaScanner(db);
      await scanner.indexSingleFile(path);
      if (!mounted) return;
      ref.read(browserRefreshSignalProvider.notifier).state++;
      ref.read(selectionProvider.notifier).state = null;
      ref.read(browserModeProvider.notifier).state = BrowserMode.timeline;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('导入失败: $e')));
      }
    } finally {
      if (mounted) {
        ref.read(scanStateProvider.notifier).state = null;
      }
    }
  }

  void _showDuplicateDialog(MediaItem existing) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('文件已存在'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('该文件（按内容 MD5 判定）已归档在下方位置：'),
            const SizedBox(height: 8),
            SelectableText(existing.filePath,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Text('已归档于 ${existing.indexedAt}',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _scanFolder(p.dirname(existing.filePath));
            },
            child: const Text('查看位置'),
          ),
        ],
      ),
    );
  }

  Future<void> _reconcileAll() async {
    if (!mounted) return;
    await _showTaskProgressDialog(
      context,
      ref,
      title: '全库对账',
      completedMessage: '对账完成，{} 个文件标记为缺失',
      run: (onProgress) async {
        final db = ref.read(databaseProvider);
        onProgress('对账中…', 0, 1);
        final missing = await db.reconcileAll(
          onProgress: (current, total) {
            onProgress('对账中 $current/$total', current, total);
          },
        );
        onProgress('更新时间轴索引中…', 0, 0);
        await db.rebuildDateIndexes();
        return missing;
      },
    );
  }

  /// 全库重新分析区域：把所有带 GPS 的 EXIF 行用离线 RegionResolver 重新
  /// 反查为省/市/县，并回写数据库。完成后刷新浏览器列表。
  Future<void> _reAnalyzeRegions() async {
    if (!mounted) return;
    await _showTaskProgressDialog(
      context,
      ref,
      title: '重新分析区域',
      completedMessage: '区域分析完成，共处理 {} 条 EXIF',
      run: (onProgress) async {
        final db = ref.read(databaseProvider);
        final scanner = MediaScanner(db);
        onProgress('加载离线地图…', 0, 0);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final updated = await scanner.reAnalyzeAllRegions(
          onProgress: (current, total) {
            onProgress('分析中 $current/$total', current, total);
          },
        );
        return updated;
      },
    );
  }

  /// 全库缩略图扫描：检测并重新生成所有缺失的缩略图
  Future<void> _regenerateAllThumbnails() async {
    if (!mounted) return;
    await _showTaskProgressDialog(
      context,
      ref,
      title: '全库缩略图扫描',
      completedMessage: '缩略图扫描完成，共生成 {} 张缩略图',
      run: (onProgress) async {
        final db = ref.read(databaseProvider);
        final scanner = MediaScanner(db);
        final generated = await scanner.generateMissingThumbnails(
          onProgress: (current, total, fileName) {
            onProgress(fileName, current, total);
          },
        );
        return generated;
      },
    );
  }

  /// 批量重新生成缩略图：对选中的文件重新生成缩略图
  Future<void> _batchRegenerateThumbnails() async {
    final selection = ref.read(selectionProvider);
    if (selection == null || selection.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先选择要处理的文件')),
        );
      }
      return;
    }

    await _showTaskProgressDialog(
      context,
      ref,
      title: '批量生成缩略图',
      completedMessage: '批量缩略图生成完成，共处理 {} 个文件',
      run: (onProgress) async {
        final db = ref.read(databaseProvider);
        final scanner = MediaScanner(db);
        int count = 0;
        final ids = selection.toList();
        final total = ids.length;
        for (int i = 0; i < total; i++) {
          final id = ids[i];
          onProgress('生成缩略图 $i/$total', i, total);

          // 获取文件信息
          final items = await (db.select(db.mediaItems)
                ..where((t) => t.id.equals(id)))
              .get();
          if (items.isEmpty) continue;
          final item = items.first;

          // 重新生成缩略图
          final file = File(item.filePath);
          if (await file.exists()) {
            final mediaId =
                (item.md5?.isNotEmpty ?? false) ? item.md5! : item.id.toString();
            final thumbPath = await scanner.generateThumbnail(file, mediaId);
            if (thumbPath != null) {
              await db.updateMedia(
                  id, MediaItemsCompanion(thumbnailPath: Value(thumbPath)));
              count++;
            }
          }
        }
        return count;
      },
    );
  }

  Future<void> _scanFolder(String folder) async {
    final db = ref.read(databaseProvider);
    final scanner = MediaScanner(db);
    final controller = ScanController(db);

    ref.read(scanControllerProvider.notifier).state = controller;
    ref.read(scanStateProvider.notifier).state =
        const ScanProgress(current: 0, total: 0, currentFile: '');
    try {
      await for (final progress in scanner.scanFolder(
        folder,
        controller: controller,
      )) {
        if (!mounted) break;
        ref.read(scanStateProvider.notifier).state = progress;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('扫描失败: $e')));
      }
    } finally {
      if (mounted) {
        ref.read(scanStateProvider.notifier).state = null;
        ref.read(scanControllerProvider.notifier).state = null;
      }
      controller.dispose();
    }
    if (mounted) ref.read(browserRefreshSignalProvider.notifier).state++;
  }

  void _handleContextAction(String action, MediaItemWithMeta item) async {
    switch (action) {
      case 'open_detail':
        showDialog(
          context: context,
          builder: (_) => _MediaDetailDialogInline(meta: item),
        );
        break;
      case 'add_tag':
        final saved = await showTagEditorDialog(context, items: [item.item]);
        if (saved) {
          ref.read(browserRefreshSignalProvider.notifier).state++;
        }
        break;
      case 'soft_delete':
        await _softDeleteOne(item);
        break;
    }
  }

  Future<void> _softDeleteOne(MediaItemWithMeta item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('从归档中移除？'),
        content: Text('将 ${p.basename(item.item.filePath)} 从数据库归档中移除（磁盘文件保留）。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton.tonal(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('移除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(databaseProvider).softDeleteMedia([item.item.id]);
      ref.read(browserRefreshSignalProvider.notifier).state++;
    }
  }

  // ── 多选 ──

  Future<void> _batchAddTags() async {
    final selection = ref.read(selectionProvider);
    if (selection == null || selection.isEmpty) return;
    final db = ref.read(databaseProvider);
    final items = await (db.select(db.mediaItems)
          ..where((t) => t.id.isIn(selection.toList())))
        .get();
    await showTagEditorDialog(context, items: items);
    ref.read(browserRefreshSignalProvider.notifier).state++;
  }

  Future<void> _batchDelete() async {
    final selection = ref.read(selectionProvider);
    if (selection == null || selection.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('批量移除'),
        content: Text('将 ${selection.length} 个文件从归档中移除（磁盘文件保留）。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton.tonal(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('移除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(databaseProvider).softDeleteMedia(selection.toList());
    ref.read(selectionProvider.notifier).state = null;
    ref.read(browserRefreshSignalProvider.notifier).state++;
  }
}

// 顶层的"导入单文件"MD5 计算（避免循环 import）
Future<String> _md5OfFile(String path) => Md5Service.Md5Helper.compute(path);

// ─────────────────────────────────────────────
// 模式侧边栏
// ─────────────────────────────────────────────

class _ModeSidebar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(browserModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: isDark ? const Color(0xFF1B1C29) : Colors.white.withOpacity(0.4),
      child: Column(
        children: [
          // ─ 模式切换（圆润胶囊） ─
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2A2B3D)
                    : scheme.surfaceVariant.withOpacity(0.6),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: BrowserMode.values.map((m) {
                  final selected = mode == m;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (mode != m) {
                          ref.read(browserModeProvider.notifier).state = m;
                          ref.read(selectionProvider.notifier).state = null;
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? scheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: scheme.primary.withOpacity(0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _iconForMode(m),
                              size: 16,
                              color: selected
                                  ? scheme.onPrimary
                                  : (isDark
                                      ? Colors.white70
                                      : scheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _labelForMode(m),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: selected
                                    ? scheme.onPrimary
                                    : (isDark
                                        ? Colors.white70
                                        : scheme.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Divider(height: 1, color: isDark ? Colors.white12 : null),
          Expanded(
            child: switch (mode) {
              BrowserMode.timeline => const _TimelineBucketList(),
              BrowserMode.folder => const _FolderTreeView(),
              BrowserMode.tag => const _TagList(),
            },
          ),
        ],
      ),
    );
  }

  IconData _iconForMode(BrowserMode m) {
    switch (m) {
      case BrowserMode.timeline:
        return Icons.timeline;
      case BrowserMode.folder:
        return Icons.folder_outlined;
      case BrowserMode.tag:
        return Icons.label_outline;
    }
  }

  String _labelForMode(BrowserMode m) {
    switch (m) {
      case BrowserMode.timeline:
        return '时间轴';
      case BrowserMode.folder:
        return '文件夹';
      case BrowserMode.tag:
        return '标签';
    }
  }
}

/// 胶囊 AppBar：圆角浮动 + 毛玻璃
class _CapsuleAppBar extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final List<Widget> actions;
  const _CapsuleAppBar({
    required this.leading,
    required this.title,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E1F2D).withOpacity(0.85)
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
      child: Row(
        children: [
          if (leading != null) leading!,
          const SizedBox(width: 8),
          Expanded(
              child: DefaultTextStyle.merge(
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            child: title,
          )),
          ...actions,
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// 浏览器顶部文件名搜索框
class _SearchBar extends ConsumerStatefulWidget {
  const _SearchBar();

  @override
  ConsumerState<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends ConsumerState<_SearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(searchFiltersProvider).filename,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(searchFiltersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasAny = !filters.isEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : Colors.white.withOpacity(0.4),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.3),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.search,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: '按文件名搜索…',
                  ),
                  onChanged: (v) {
                    ref.read(searchFiltersProvider.notifier).state =
                        filters.copyWith(filename: v);
                  },
                ),
              ),
              // 命中条数
              Consumer(
                builder: (context, ref, _) {
                  final asyncList = ref.watch(browserMediaProvider);
                  return asyncList.maybeWhen(
                    data: (items) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '${items.length}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  );
                },
              ),
              // 高级搜索按钮（带角标）
              _FilterIconButton(
                badge: filters.activeExtras,
                onTap: () => _openAdvancedFilter(),
              ),
              if (hasAny)
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  tooltip: '清空全部搜索',
                  onPressed: () {
                    _controller.clear();
                    ref.read(searchFiltersProvider.notifier).state =
                        const SearchFilters();
                    setState(() {});
                  },
                ),
            ],
          ),
          // 活跃的非文件名条件 → chip 摘要行
          if (filters.activeExtras > 0) _ActiveChipsRow(filters: filters),
        ],
      ),
    );
  }

  Future<void> _openAdvancedFilter() async {
    await showDialog(
      context: context,
      builder: (_) => const _AdvancedFilterDialog(),
    );
  }
}

/// 带角标的过滤按钮
class _FilterIconButton extends StatelessWidget {
  final int badge;
  final VoidCallback onTap;
  const _FilterIconButton({required this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.tune, size: 18),
          tooltip: '高级搜索',
          onPressed: onTap,
        ),
        if (badge > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$badge',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 搜索栏下方：4 个非文件名条件的可删除 chip
class _ActiveChipsRow extends ConsumerWidget {
  final SearchFilters filters;
  const _ActiveChipsRow({required this.filters});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chips = <Widget>[];

    if (filters.dateRange != null) {
      final s = _fmtDate(filters.dateRange!.start);
      final e = _fmtDate(filters.dateRange!.end);
      chips.add(_chip(
        context,
        ref,
        '时间: $s ~ $e',
        onDelete: () => ref.read(searchFiltersProvider.notifier).state =
            filters.copyWith(clearDateRange: true),
      ));
    }
    if (filters.cameras.isNotEmpty) {
      chips.add(_chip(
        context,
        ref,
        '设备: ${filters.cameras.length} 项',
        onDelete: () => ref.read(searchFiltersProvider.notifier).state =
            filters.copyWith(cameras: const {}),
      ));
    }
    if (filters.cities.isNotEmpty) {
      chips.add(_chip(
        context,
        ref,
        '城市: ${filters.cities.length} 项',
        onDelete: () => ref.read(searchFiltersProvider.notifier).state =
            filters.copyWith(cities: const {}),
      ));
    }
    if (filters.tagIds.isNotEmpty) {
      chips.add(_chip(
        context,
        ref,
        '标签: ${filters.tagIds.length} 项',
        onDelete: () => ref.read(searchFiltersProvider.notifier).state =
            filters.copyWith(tagIds: const {}),
      ));
    }
    if (filters.fileType != null) {
      chips.add(_chip(
        context,
        ref,
        filters.fileType == 'image' ? '仅图片' : '仅视频',
        onDelete: () => ref.read(searchFiltersProvider.notifier).state =
            filters.copyWith(clearFileType: true),
      ));
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(spacing: 6, runSpacing: 4, children: chips),
    );
  }

  Widget _chip(BuildContext context, WidgetRef ref, String label,
      {required VoidCallback onDelete}) {
    return InputChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onDeleted: onDelete,
      deleteIconColor: Theme.of(context).colorScheme.onSurfaceVariant,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

String _fmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 自带日历按钮 + 可编辑文本的日期输入控件。
/// 用普通 TextField 替代系统 DateRangePicker，
/// 解决系统组件文本框无法用键盘删除内容的问题。
class _DateField extends StatefulWidget {
  final String label;
  final DateTime? value;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime?> onChanged;

  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<_DateField> {
  late final TextEditingController _controller;
  // 标记本次 controller.text 变更来自外部，避免 onChanged 回环
  bool _internalChange = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _fmt(widget.value));
  }

  @override
  void didUpdateWidget(covariant _DateField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _internalChange = true;
      _controller.text = _fmt(widget.value);
      _internalChange = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _fmt(DateTime? d) {
    if (d == null) return '';
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  DateTime? _parse(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    final m = RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})$').firstMatch(t);
    if (m == null) return null;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    return DateTime(y, mo, d);
  }

  Future<void> _pick() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.value ?? DateTime.now(),
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
    );
    if (picked != null) widget.onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: 'YYYY-MM-DD',
        isDense: true,
        suffixIcon: IconButton(
          icon: const Icon(Icons.calendar_today, size: 16),
          tooltip: '选择日期',
          onPressed: _pick,
        ),
      ),
      onChanged: (v) {
        if (_internalChange) return;
        final parsed = _parse(v);
        if (parsed != null) widget.onChanged(parsed);
      },
    );
  }
}

/// 高级搜索弹窗：设备 / 城市 / 拍摄时间 / 标签（多选）
class _AdvancedFilterDialog extends ConsumerStatefulWidget {
  const _AdvancedFilterDialog();

  @override
  ConsumerState<_AdvancedFilterDialog> createState() =>
      _AdvancedFilterDialogState();
}

class _AdvancedFilterDialogState extends ConsumerState<_AdvancedFilterDialog> {
  late SearchFilters _draft;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(searchFiltersProvider);
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.pop(context),
      },
      child: Focus(
        autofocus: true,
        child: AlertDialog(
          title: const Text('高级搜索'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _SectionLabel('拍摄设备（多选）'),
              _MultiChips(
                future: ref.watch(distinctCamerasProvider),
                selected: _draft.cameras,
                onToggle: (v) => setState(() {
                  final next = {..._draft.cameras};
                  if (!next.add(v)) next.remove(v);
                  _draft = _draft.copyWith(cameras: next);
                }),
                emptyText: '暂无 EXIF 设备数据',
              ),
              const SizedBox(height: 14),
              _SectionLabel('城市（多选）'),
              _MultiChips(
                future: ref.watch(distinctCitiesProvider),
                selected: _draft.cities,
                onToggle: (v) => setState(() {
                  final next = {..._draft.cities};
                  if (!next.add(v)) next.remove(v);
                  _draft = _draft.copyWith(cities: next);
                }),
                emptyText: '暂无 EXIF 城市数据',
              ),
              const SizedBox(height: 14),
              _SectionLabel('拍摄时间'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _DateField(
                      label: '开始',
                      value: _draft.dateRange?.start,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
                      onChanged: (d) {
                        if (d == null) return;
                        setState(() {
                          final end = _draft.dateRange?.end;
                          // 若结束早于开始，纠正为同一天
                          _draft = _draft.copyWith(
                            dateRange: DateTimeRange(
                              start: d,
                              end: (end == null || end.isBefore(d)) ? d : end,
                            ),
                          );
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DateField(
                      label: '结束',
                      value: _draft.dateRange?.end,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
                      onChanged: (d) {
                        if (d == null) return;
                        setState(() {
                          final start = _draft.dateRange?.start;
                          _draft = _draft.copyWith(
                            dateRange: DateTimeRange(
                              start: (start == null || start.isAfter(d))
                                  ? d
                                  : start,
                              end: d,
                            ),
                          );
                        });
                      },
                    ),
                  ),
                  if (_draft.dateRange != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      tooltip: '清除时间区间',
                      onPressed: () => setState(
                          () => _draft = _draft.copyWith(clearDateRange: true)),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _SectionLabel('标签（多选，OR）'),
              _TagChips(
                selected: _draft.tagIds,
                onToggle: (id) => setState(() {
                  final next = {..._draft.tagIds};
                  if (!next.add(id)) next.remove(id);
                  _draft = _draft.copyWith(tagIds: next);
                }),
              ),
              const SizedBox(height: 14),
              _SectionLabel('媒体类型'),
              Row(
                children: [
                  ChoiceChip(
                    label: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.image_outlined, size: 16),
                      const SizedBox(width: 4),
                      const Text('图片', style: TextStyle(fontSize: 11)),
                    ]),
                    selected: _draft.fileType == 'image',
                    onSelected: (_) => setState(() => _draft =
                        _draft.copyWith(
                            fileType: _draft.fileType == 'image'
                                ? null
                                : 'image')),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.videocam_outlined, size: 16),
                      const SizedBox(width: 4),
                      const Text('视频', style: TextStyle(fontSize: 11)),
                    ]),
                    selected: _draft.fileType == 'video',
                    onSelected: (_) => setState(() => _draft =
                        _draft.copyWith(
                            fileType: _draft.fileType == 'video'
                                ? null
                                : 'video')),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() {
            _draft = _draft.copyWith(
              cameras: const {},
              cities: const {},
              tagIds: const {},
              clearDateRange: true,
              clearFileType: true,
            );
          }),
          child: const Text('清空'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            ref.read(searchFiltersProvider.notifier).state = _draft;
            Navigator.pop(context);
          },
          child: const Text('应用'),
        ),
      ],
      ),
    ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

class _MultiChips extends StatelessWidget {
  final AsyncValue<List<String>> future;
  final Set<String> selected;
  final void Function(String) onToggle;
  final String emptyText;
  const _MultiChips({
    required this.future,
    required this.selected,
    required this.onToggle,
    required this.emptyText,
  });
  @override
  Widget build(BuildContext context) {
    return future.when(
      loading: () => const SizedBox(
          height: 32, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Text('$e', style: const TextStyle(color: Colors.red), maxLines: 2, overflow: TextOverflow.ellipsis),
      data: (items) => items.isEmpty
          ? Text(emptyText,
              style: TextStyle(
                  fontSize: 12, color: Theme.of(context).colorScheme.outline))
          : Wrap(
              spacing: 6,
              runSpacing: 4,
              children: items.map((v) {
                final on = selected.contains(v);
                return FilterChip(
                  label: Text(v, style: const TextStyle(fontSize: 11)),
                  selected: on,
                  onSelected: (_) => onToggle(v),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
    );
  }
}

class _TagChips extends ConsumerWidget {
  final Set<int> selected;
  final void Function(int) onToggle;
  const _TagChips({required this.selected, required this.onToggle});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(allTagsProvider);
    return tagsAsync.when(
      loading: () => const SizedBox(
          height: 32, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Text('$e', style: const TextStyle(color: Colors.red), maxLines: 2, overflow: TextOverflow.ellipsis),
      data: (tags) => tags.isEmpty
          ? Text('还没有标签，请到侧边栏创建',
              style: TextStyle(
                  fontSize: 12, color: Theme.of(context).colorScheme.outline))
          : Wrap(
              spacing: 6,
              runSpacing: 4,
              children: tags.map((t) {
                final on = selected.contains(t.id);
                return FilterChip(
                  label: Text(t.name, style: const TextStyle(fontSize: 11)),
                  selected: on,
                  selectedColor: _hex(t.color)?.withOpacity(0.3),
                  avatar:
                      CircleAvatar(radius: 6, backgroundColor: _hex(t.color)),
                  onSelected: (_) => onToggle(t.id),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
    );
  }
}

/// 胶囊动作按钮
class _CapsuleIconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;
  final bool enabled;
  const _CapsuleIconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = color;
    final isEnabled = enabled && onTap != null;
    return Tooltip(
      message: isEnabled ? tooltip : '$tooltip（扫描中不可用）',
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isEnabled
                ? (c != null
                    ? c.withOpacity(0.1)
                    : Theme.of(context).colorScheme.primary.withOpacity(0.08))
                : Theme.of(context).disabledColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon,
              size: 18,
              color: isEnabled
                  ? (c ?? Theme.of(context).colorScheme.primary)
                  : Theme.of(context).disabledColor),
        ),
      ),
    );
  }
}

/// 顶部视图模式切换器（宫格图标 / 列表视图）
class _ViewModeToggle extends StatelessWidget {
  final ViewMode current;
  final void Function(ViewMode) onChanged;
  const _ViewModeToggle({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(3),
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
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ViewMode.values.where((v) => v != ViewMode.large).map((v) {
          final selected = v == current;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: GestureDetector(
              onTap: () => onChanged(v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? scheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_icon(v),
                        size: 14,
                        color: selected
                            ? scheme.onPrimary
                            : isDark
                                ? Colors.white.withOpacity(0.7)
                                : scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(_label(v),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
                          color: selected
                              ? scheme.onPrimary
                              : isDark
                                  ? Colors.white.withOpacity(0.7)
                                  : scheme.onSurfaceVariant,
                        )),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _icon(ViewMode v) {
    switch (v) {
      case ViewMode.large:
        return Icons.dashboard_outlined;
      case ViewMode.medium:
        return Icons.grid_view_outlined;
      case ViewMode.list:
        return Icons.view_list_outlined;
    }
  }

  String _label(ViewMode v) {
    switch (v) {
      case ViewMode.large:
        return '大图';
      case ViewMode.medium:
        return '宫格';
      case ViewMode.list:
        return '列表';
    }
  }
}

/// 顶部排序按钮：下拉选取方式，列出所有 6 种排序选项（时间/大小/文件名 × 升/降序）。
class _SortButton extends StatelessWidget {
  final BrowserSort current;
  final void Function(BrowserSort) onChanged;
  const _SortButton({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dimIcon = _dimIcon(current);
    final dimLabel = _dimLabel(current);
    final desc = current.name.contains('Desc');

    return PopupMenuButton<BrowserSort>(
      initialValue: current,
      tooltip: '排序方式',
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outline.withOpacity(0.2)),
      ),
      elevation: 8,
      offset: const Offset(0, 8),
      onSelected: onChanged,
      itemBuilder: (_) => [
        // 时间排序
        PopupMenuItem<BrowserSort>(
          value: BrowserSort.timeDesc,
          child: _SortMenuItem(
            icon: Icons.schedule_outlined,
            label: '时间',
            suffix: '最新',
            selected: current == BrowserSort.timeDesc,
          ),
        ),
        PopupMenuItem<BrowserSort>(
          value: BrowserSort.timeAsc,
          child: _SortMenuItem(
            icon: Icons.schedule_outlined,
            label: '时间',
            suffix: '最早',
            selected: current == BrowserSort.timeAsc,
          ),
        ),
        const PopupMenuDivider(height: 8),
        // 大小排序
        PopupMenuItem<BrowserSort>(
          value: BrowserSort.sizeDesc,
          child: _SortMenuItem(
            icon: Icons.data_usage_outlined,
            label: '大小',
            suffix: '从大到小',
            selected: current == BrowserSort.sizeDesc,
          ),
        ),
        PopupMenuItem<BrowserSort>(
          value: BrowserSort.sizeAsc,
          child: _SortMenuItem(
            icon: Icons.data_usage_outlined,
            label: '大小',
            suffix: '从小到大',
            selected: current == BrowserSort.sizeAsc,
          ),
        ),
        const PopupMenuDivider(height: 8),
        // 名称排序
        PopupMenuItem<BrowserSort>(
          value: BrowserSort.nameDesc,
          child: _SortMenuItem(
            icon: Icons.sort_by_alpha_outlined,
            label: '名称',
            suffix: 'Z-A',
            selected: current == BrowserSort.nameDesc,
          ),
        ),
        PopupMenuItem<BrowserSort>(
          value: BrowserSort.nameAsc,
          child: _SortMenuItem(
            icon: Icons.sort_by_alpha_outlined,
            label: '名称',
            suffix: 'A-Z',
            selected: current == BrowserSort.nameAsc,
          ),
        ),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: scheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(dimIcon, size: 16, color: scheme.primary),
            const SizedBox(width: 4),
            Text(
              dimLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              desc ? '↓' : '↑',
              style: TextStyle(fontSize: 12, color: scheme.primary),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down_outlined,
                size: 16, color: scheme.primary),
          ],
        ),
      ),
    );
  }

  IconData _dimIcon(BrowserSort s) {
    switch (s) {
      case BrowserSort.timeDesc:
      case BrowserSort.timeAsc:
        return Icons.schedule_outlined;
      case BrowserSort.sizeDesc:
      case BrowserSort.sizeAsc:
        return Icons.data_usage_outlined;
      case BrowserSort.nameDesc:
      case BrowserSort.nameAsc:
        return Icons.sort_by_alpha_outlined;
    }
  }

  String _dimLabel(BrowserSort s) {
    switch (s) {
      case BrowserSort.timeDesc:
      case BrowserSort.timeAsc:
        return '时间';
      case BrowserSort.sizeDesc:
      case BrowserSort.sizeAsc:
        return '大小';
      case BrowserSort.nameDesc:
      case BrowserSort.nameAsc:
        return '名称';
    }
  }
}

/// 排序菜单项：图标 + 标签 + 后缀说明
class _SortMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String suffix;
  final bool selected;
  const _SortMenuItem({
    required this.icon,
    required this.label,
    required this.suffix,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Icon(icon,
              size: 16,
              color: selected ? scheme.primary : scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? scheme.primary : scheme.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            suffix,
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          if (selected) Icon(Icons.check, size: 16, color: scheme.primary),
        ],
      ),
    );
  }
}

class _TimelineBucketList extends ConsumerStatefulWidget {
  const _TimelineBucketList();
  @override
  ConsumerState<_TimelineBucketList> createState() =>
      _TimelineBucketListState();
}

enum _TimelineViewMode { list, calendar }

class _TimelineBucketListState extends ConsumerState<_TimelineBucketList> {
  _TimelineViewMode _view = _TimelineViewMode.list;
  int _calYear = 0;
  int _calMonth = 0;

  // 缓存每日索引数据
  Map<String, int> _dailyCounts = {};
  bool _dailyLoaded = false;

  Future<void> _loadDailyIndexes() async {
    if (_dailyLoaded) return;
    final db = ref.read(databaseProvider);
    final indexes = await db.getDateIndexes();
    if (!mounted) return;
    setState(() {
      _dailyCounts = {for (final idx in indexes) idx.dateKey: idx.count};
      _dailyLoaded = true;
    });
  }

  void _onBucketTap(String bucket) {
    ref.read(activeTimelineBucketProvider.notifier).state = bucket;
    final link = ref.read(timelineLinkProvider);

    final ctx = link.bucketKeys[bucket]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 300), alignment: 0.1);
      return;
    }

    final scroll = link.scrollController;
    if (scroll == null || !scroll.hasClients) return;
    final total = link.totalItemCount;
    final firstIdx = link.bucketFirstIndex[bucket];
    if (total == 0 || firstIdx == null) return;
    final pos = scroll.position;
    final avgItemH = pos.maxScrollExtent > 0 && pos.maxScrollExtent.isFinite
        ? (pos.maxScrollExtent / total).clamp(60.0, 600.0)
        : 200.0;
    final target = (firstIdx * avgItemH).clamp(0.0, pos.maxScrollExtent);
    scroll.jumpTo(target);

    int retries = 0;
    void tryPrecise(Duration _) {
      if (!mounted) return;
      final newCtx =
          ref.read(timelineLinkProvider).bucketKeys[bucket]?.currentContext;
      if (newCtx != null) {
        Scrollable.ensureVisible(newCtx,
            duration: const Duration(milliseconds: 300), alignment: 0.1);
        return;
      }
      if (++retries < 5) {
        WidgetsBinding.instance.addPostFrameCallback(tryPrecise);
      }
    }
    WidgetsBinding.instance.addPostFrameCallback(tryPrecise);
  }

  @override
  Widget build(BuildContext context) {
    final bucketsAsync = ref.watch(timelineBucketsProvider);
    final activeBucket = ref.watch(activeTimelineBucketProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // ── 模式切换按钮 ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              const Spacer(),
              _ViewToggle(
                view: _view,
                onChanged: (v) {
                  setState(() => _view = v);
                  if (v == _TimelineViewMode.calendar) {
                    _loadDailyIndexes();
                  }
                },
              ),
            ],
          ),
        ),
        // ── 内容 ──
        Expanded(
          child: bucketsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, _) => Center(
              child: Text('$e', style: TextStyle(
                  fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
            ),
            data: (buckets) {
              if (buckets.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    '暂无数据\n\n点击右上角导入文件夹开始整理。',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54
                          : Theme.of(context).colorScheme.outline,
                    ),
                  ),
                );
              }
              if (_view == _TimelineViewMode.calendar) {
                return _buildCalendar(buckets, activeBucket);
              }
              return _buildList(buckets, activeBucket, isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildList(List<MonthlyBucket> buckets, String? activeBucket, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: buckets.length,
      itemBuilder: (_, i) {
        final bucket = buckets[i];
        final selected = bucket.dateKey == activeBucket;
        return InkWell(
          onTap: () => _onBucketTap(bucket.dateKey),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bucket.dateKey,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? Theme.of(context).colorScheme.primary : null,
                  ),
                ),
                Text('${bucket.count} 张',
                    style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white54 : Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalendar(List<MonthlyBucket> buckets, String? activeBucket) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 取最新月份为默认
    if (_calYear == 0 && buckets.isNotEmpty) {
      final latest = buckets.first.dateKey; // "YYYY-MM"
      final parts = latest.split('-');
      _calYear = int.parse(parts[0]);
      _calMonth = int.parse(parts[1]);
    }

    final monthKey = '$_calYear-${_calMonth.toString().padLeft(2, '0')}';
    final monthBucket = buckets.where((b) => b.dateKey == monthKey).firstOrNull;

    // 当月每日计数
    final prefix = '$monthKey-';
    final dailyInMonth = _dailyCounts.entries
        .where((e) => e.key.startsWith(prefix))
        .map((e) => MapEntry(e.key.substring(prefix.length), e.value))
        .toList();

    return Column(
      children: [
        // ── 月份导航 ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () {
                  setState(() {
                    _calMonth--;
                    if (_calMonth < 1) { _calMonth = 12; _calYear--; }
                  });
                },
              ),
              Expanded(
                child: Text(
                  '$monthKey · ${monthBucket?.count ?? 0}张',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () {
                  setState(() {
                    _calMonth++;
                    if (_calMonth > 12) { _calMonth = 1; _calYear++; }
                  });
                  if (_calYear * 12 + _calMonth > DateTime.now().year * 12 + DateTime.now().month) {
                    _calMonth = DateTime.now().month;
                    _calYear = DateTime.now().year;
                  }
                },
              ),
            ],
          ),
        ),
        // ── 星期表头 ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: '一二三四五六日'
                .split('')
                .map((d) => Expanded(
                      child: Text(d,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white54 : Colors.grey)),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 2),
        // ── 日历网格 ──
        Expanded(
          child: _buildCalendarGrid(monthKey, isDark, dailyInMonth),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(
      String monthKey, bool isDark, List<MapEntry<String, int>> dailyInMonth) {
    final dayCount = {for (final e in dailyInMonth) e.key: e.value};
    final daysInMonth = _daysInMonth(_calYear, _calMonth);
    final firstWeekday = DateTime(_calYear, _calMonth, 1).weekday; // 1=mon...7=sun
    // 转为周日为 7 的模式
    final startCol = firstWeekday == 7 ? 0 : firstWeekday; // mon=1 → col=1, sun=0

    // 最多 6 行
    final cells = <Widget>[];
    // 空白填充
    for (int c = 0; c < startCol; c++) {
      cells.add(const SizedBox.shrink());
    }
    for (int d = 1; d <= daysInMonth; d++) {
      final dayStr = d.toString().padLeft(2, '0');
      final count = dayCount[dayStr];
      cells.add(_CalendarDay(
        day: d,
        count: count,
        isDark: isDark,
        onTap: count != null ? () => _onBucketTap(monthKey) : null,
      ));
    }

    // 填充剩余空
    final total = (cells.length / 7).ceil() * 7;
    while (cells.length < total) {
      cells.add(const SizedBox.shrink());
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GridView.count(
        crossAxisCount: 7,
        childAspectRatio: 1.0,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        children: cells,
      ),
    );
  }

  int _daysInMonth(int y, int m) {
    if (m == 2) {
      if (y % 4 == 0 && (y % 100 != 0 || y % 400 == 0)) return 29;
      return 28;
    }
    if ([4, 6, 9, 11].contains(m)) return 30;
    return 31;
  }
}

/// 日历日格子
class _CalendarDay extends StatelessWidget {
  final int day;
  final int? count;
  final bool isDark;
  final VoidCallback? onTap;

  const _CalendarDay({
    required this.day,
    this.count,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhotos = count != null && count! > 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: hasPhotos
              ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
              : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontSize: 11,
                fontWeight: hasPhotos ? FontWeight.w500 : FontWeight.w400,
                color: hasPhotos
                    ? Theme.of(context).colorScheme.primary
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
            ),
            if (hasPhotos)
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 8,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 列表/日历切换按钮
class _ViewToggle extends StatelessWidget {
  final _TimelineViewMode view;
  final ValueChanged<_TimelineViewMode> onChanged;

  const _ViewToggle({required this.view, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Colors.white60 : Colors.grey;
    final activeColor = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: 52,
      height: 24,
      child: GestureDetector(
        onTap: () => onChanged(
            view == _TimelineViewMode.list
                ? _TimelineViewMode.calendar
                : _TimelineViewMode.list),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2B3D) : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Icon(Icons.list, size: 12,
                    color: view == _TimelineViewMode.list ? activeColor : color),
              ),
              Expanded(
                child: Icon(Icons.calendar_month, size: 12,
                    color: view == _TimelineViewMode.calendar ? activeColor : color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 文件夹树视图（可展开/收起，层级结构）
// ─────────────────────────────────────────────

/// 树节点展开状态 Provider（按路径缓存展开/折叠）
final _folderExpandStateProvider =
    StateProvider<Set<String>>((_) => <String>{});

class _FolderTreeView extends ConsumerWidget {
  const _FolderTreeView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treeAsync = ref.watch(folderTreeProvider);
    final current = ref.watch(currentFolderProvider);
    final expanded = ref.watch(_folderExpandStateProvider);

    return treeAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, st) => Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_off_outlined,
                  size: 32, color: Colors.grey),
              const SizedBox(height: 8),
              const Text('加载失败',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey)),
              const SizedBox(height: 6),
              Text(
                e.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
      data: (root) {
        // 如果根是虚拟的，显示子节点列表
        final topNodes = root.path.isEmpty ? root.children : [root];
        if (topNodes.isEmpty) {
          return const _EmptyHint(text: '还没有文件夹');
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: topNodes.length,
          itemBuilder: (_, i) => _FolderTreeNodeWidget(
            node: topNodes[i],
            depth: 0,
            selectedPath: current,
            expandedSet: expanded,
          ),
        );
      },
    );
  }
}

class _FolderTreeNodeWidget extends ConsumerWidget {
  final FolderTreeNode node;
  final int depth;
  final String? selectedPath;
  final Set<String> expandedSet;

  const _FolderTreeNodeWidget({
    required this.node,
    required this.depth,
    required this.selectedPath,
    required this.expandedSet,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isExpanded = expandedSet.contains(node.path);
    final isSelected = node.path == (selectedPath ?? '');
    final hasChildren = node.children.isNotEmpty;
    final scheme = Theme.of(context).colorScheme;
    // 计算总文件数（递归）
    final totalFiles = node.totalCount;
    // 判断是否有后代选中
    final sel = selectedPath;
    final hasSelectedChild = sel != null &&
        sel.isNotEmpty &&
        node.path.isNotEmpty &&
        sel.startsWith(node.path) &&
        sel != node.path;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 当前行
        InkWell(
          onTap: () {
            if (hasChildren) {
              // 切换展开状态
              final newSet = Set<String>.from(expandedSet);
              if (isExpanded) {
                newSet.remove(node.path);
              } else {
                newSet.add(node.path);
              }
              ref.read(_folderExpandStateProvider.notifier).state = newSet;
            }
            // 选中此文件夹
            ref.read(currentFolderProvider.notifier).state = node.path;
            ref.read(selectionProvider.notifier).state = null;
          },
          child: Container(
            padding: EdgeInsets.only(
                left: 8.0 + depth * 16.0, right: 8, top: 6, bottom: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? scheme.primary.withOpacity(0.1)
                  : hasSelectedChild
                      ? scheme.primary.withOpacity(0.04)
                      : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                // 展开/折叠箭头
                SizedBox(
                  width: 18,
                  height: 18,
                  child: hasChildren
                      ? AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(Icons.chevron_right,
                              size: 16, color: scheme.onSurfaceVariant),
                        )
                      : const SizedBox(width: 18),
                ),
                const SizedBox(width: 4),
                Icon(
                  hasChildren && !isExpanded
                      ? Icons.folder_outlined
                      : Icons.folder,
                  size: 17,
                  color: isSelected
                      ? scheme.primary
                      : scheme.onSurfaceVariant.withOpacity(0.7),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    node.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? scheme.primary : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                // 显示文件数：直接文件数 + 子目录总数（如有子目录）
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (node.fileCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: scheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${node.fileCount}',
                            style: TextStyle(
                                fontSize: 9,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white70
                                    : Colors.black54),
                          ),
                        ),
                      if (node.children.isNotEmpty &&
                          totalFiles > node.fileCount) ...[
                        const SizedBox(width: 3),
                        Text(
                          '+${totalFiles - node.fileCount}',
                          style: TextStyle(
                            fontSize: 9,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white54
                                    : Colors.black45,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // 展开时渲染子节点
        if (hasChildren && isExpanded)
          ...node.children.map((child) => _FolderTreeNodeWidget(
                node: child,
                depth: depth + 1,
                selectedPath: selectedPath,
                expandedSet: expandedSet,
              )),
      ],
    );
  }
}

class _TagList extends ConsumerStatefulWidget {
  const _TagList();

  @override
  ConsumerState<_TagList> createState() => _TagListState();
}

class _TagListState extends ConsumerState<_TagList> {
  static const _presetColors = [
    '#4A90D9',
    '#E74C3C',
    '#2ECC71',
    '#F39C12',
    '#9B59B6',
    '#1ABC9C',
    '#E67E22',
    '#34495E',
  ];

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(allTagsProvider);
    final current = ref.watch(currentTagFilterProvider);
    return tagsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('$e', maxLines: 2, overflow: TextOverflow.ellipsis),
      data: (tags) => Column(
        children: [
          // ── 新建标签按钮（紧贴模式切换条） ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => _showAddTagDialog(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('新建标签', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.3),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: tags.isEmpty
                ? const _EmptyHint(text: '还没有标签\n点击"新建标签"创建')
                : ListView.builder(
                    itemCount: tags.length,
                    itemBuilder: (_, i) {
                      final t = tags[i];
                      final selected = current == t.id;
                      return ListTile(
                        dense: true,
                        selected: selected,
                        leading: CircleAvatar(
                          radius: 6,
                          backgroundColor: _hex(t.color) ?? Colors.blue,
                        ),
                        title: Text(t.name),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 16),
                          tooltip: '删除标签',
                          onPressed: () => _confirmDelete(t),
                        ),
                        onTap: () {
                          ref.read(currentTagFilterProvider.notifier).state =
                              t.id;
                          ref.read(selectionProvider.notifier).state = null;
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddTagDialog() async {
    final nameController = TextEditingController();
    final hexController = TextEditingController(text: _presetColors.first);
    String selectedColor = _presetColors.first;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('新建标签'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '标签名称',
                  hintText: '例如：风景、旅行、家人',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Text('颜色', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _presetColors.map((hex) {
                  final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedColor = hex;
                        hexController.text = hex;
                      });
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: selectedColor == hex
                            ? Border.all(color: Colors.black, width: 2)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              // 16 进制输入：单独一行，宽度足够正常编辑/删除
              TextField(
                controller: hexController,
                decoration: const InputDecoration(
                  labelText: '16 进制',
                  hintText: '#RRGGBB',
                  isDense: true,
                ),
                onChanged: (v) {
                  // 实时校验并预览；非有效输入保留文本，不强制重置
                  final hex = _normalizeHex(v);
                  if (hex != null) {
                    setState(() => selectedColor = hex);
                  }
                },
              ),
              const SizedBox(height: 8),
              // 颜色预览 + 调色盘按钮
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _hex(selectedColor) ?? Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            Theme.of(ctx).colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.palette_outlined, size: 18),
                      label: const Text('打开调色盘'),
                      onPressed: () async {
                        final picked =
                            await _showHsvPickerDialog(context, selectedColor);
                        if (picked != null) {
                          setState(() {
                            selectedColor = picked;
                            hexController.text = picked;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                await ref.read(databaseProvider).addTag(
                      name,
                      color: selectedColor,
                    );
                ref.invalidate(allTagsProvider);
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('创建'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      ref.invalidate(allTagsProvider);
      ref.read(browserRefreshSignalProvider.notifier).state++;
    }
  }

  // ── 16 进制规范化：接受 #RGB / #RRGGBB / RRGGBB / RGB ──
  String? _normalizeHex(String input) {
    var s = input.trim().toUpperCase().replaceFirst('#', '');
    if (s.length == 3) {
      s = s.split('').map((c) => '$c$c').join();
    }
    if (s.length != 6) return null;
    if (!RegExp(r'^[0-9A-F]{6}$').hasMatch(s)) return null;
    return '#$s';
  }

  // ── 调色盘：2D 饱和度/明度方格 + 色相滑块 ──
  Future<String?> _showHsvPickerDialog(
      BuildContext context, String initialHex) {
    final initColor = _hex(initialHex) ?? Colors.blue;
    return showDialog<String>(
      context: context,
      builder: (ctx) => _HsvPickerDialog(initial: initColor),
    );
  }

  Future<void> _confirmDelete(Tag tag) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除标签'),
        content: Text('删除「${tag.name}」？关联图片的标记也将一起删除。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton.tonal(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      final db = ref.read(databaseProvider);
      await (db.delete(db.tags)..where((t) => t.id.equals(tag.id))).go();
      ref.invalidate(allTagsProvider);
      ref.read(browserRefreshSignalProvider.notifier).state++;
      if (ref.read(currentTagFilterProvider) == tag.id) {
        ref.read(currentTagFilterProvider.notifier).state = null;
      }
    }
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});
  @override
  Widget build(BuildContext context) => Center(
        child: Text(text,
            style: TextStyle(
                fontSize: 12, color: Theme.of(context).colorScheme.outline)),
      );
}

Color? _hex(String hex) {
  try {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  } catch (_) {
    return null;
  }
}

// ─────────────────────────────────────────────
// 调色盘对话框：8×8 标准色卡（Material 风）
// ─────────────────────────────────────────────

class _HsvPickerDialog extends StatefulWidget {
  final Color initial;
  const _HsvPickerDialog({required this.initial});
  @override
  State<_HsvPickerDialog> createState() => _HsvPickerDialogState();
}

class _HsvPickerDialogState extends State<_HsvPickerDialog> {
  // 8 行 × 8 列 = 64 个标准色
  // 行 = 色相（红/橙/黄/绿/青/蓝/紫/粉/灰），
  // 列 = 同色相下由最浅到最深
  static const List<String> _palette = [
    // 红
    '#FFEBEE', '#FFCDD2', '#EF9A9A', '#E57373',
    '#EF5350', '#F44336', '#E53935', '#C62828',
    // 橙
    '#FFF3E0', '#FFE0B2', '#FFCC80', '#FFB74D',
    '#FFA726', '#FF9800', '#FB8C00', '#E65100',
    // 黄
    '#FFFDE7', '#FFF9C4', '#FFF59D', '#FFF176',
    '#FFEE58', '#FFEB3B', '#FDD835', '#F9A825',
    // 绿
    '#E8F5E9', '#C8E6C9', '#A5D6A7', '#81C784',
    '#66BB6A', '#4CAF50', '#43A047', '#2E7D32',
    // 青
    '#E0F7FA', '#B2EBF2', '#80DEEA', '#4DD0E1',
    '#26C6DA', '#00BCD4', '#00ACC1', '#00838F',
    // 蓝
    '#E3F2FD', '#BBDEFB', '#90CAF9', '#64B5F6',
    '#42A5F5', '#2196F3', '#1E88E5', '#1565C0',
    // 紫
    '#EDE7F6', '#D1C4E9', '#B39DDB', '#9575CD',
    '#7E57C2', '#673AB7', '#5E35B1', '#4527A0',
    // 粉
    '#FCE4EC', '#F8BBD0', '#F48FB1', '#F06292',
    '#EC407A', '#E91E63', '#D81B60', '#AD1457',
  ];

  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = _toHex(widget.initial);
  }

  static String _toHex(Color c) {
    String h(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
    return '#${h(c.red)}${h(c.green)}${h(c.blue)}';
  }

  Color _parse(String hex) => Color(int.parse(hex.replaceFirst('#', '0xFF')));

  @override
  Widget build(BuildContext context) {
    final selectedColor = _parse(_selected);
    return AlertDialog(
      title: const Text('调色盘'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GridView.count(
              crossAxisCount: 8,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1,
              children: _palette.map((hex) {
                final on = _selected == hex;
                return GestureDetector(
                  onTap: () => setState(() => _selected = hex),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _parse(hex),
                      borderRadius: BorderRadius.circular(6),
                      border: on
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 3,
                            )
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selectedColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.3),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(_selected,
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
            onPressed: () => Navigator.pop(context, _selected),
            child: const Text('确定')),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// 文件夹模式专用内容：路径栏 + 子目录 + 媒体
// ─────────────────────────────────────────────

class _FolderModeContent extends ConsumerStatefulWidget {
  final Widget viewWidget;
  const _FolderModeContent({required this.viewWidget});

  @override
  ConsumerState<_FolderModeContent> createState() => _FolderModeContentState();
}

class _FolderModeContentState extends ConsumerState<_FolderModeContent> {
  @override
  Widget build(BuildContext context) {
    final folder = ref.watch(currentFolderProvider);
    final subFoldersAsync = ref.watch(subFoldersProvider);
    final viewMode = ref.watch(viewModeProvider);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // 路径栏
        if (folder != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(
                bottom:
                    BorderSide(color: scheme.outlineVariant.withOpacity(0.3)),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.folder_outlined, size: 16, color: scheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showPathInput(context),
                    child: Tooltip(
                      message: '点击输入新路径',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              scheme.surfaceContainerHighest.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                folder.isEmpty ? '全部文件夹' : folder,
                                style: TextStyle(
                                    fontSize: 11, color: scheme.onSurface),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.edit_outlined,
                                size: 12, color: scheme.outline),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // 子目录区域（根据 viewMode 切换显示方式）
        subFoldersAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (subs) {
            if (subs.isEmpty) return const SizedBox.shrink();
            return _buildSubFoldersView(subs, viewMode, scheme, folder);
          },
        ),

        // 主媒体内容区
        Expanded(child: widget.viewWidget),
      ],
    );
  }

  Widget _buildSubFoldersView(List<SubFolderEntry> subs, ViewMode viewMode,
      ColorScheme scheme, String? folder) {
    switch (viewMode) {
      case ViewMode.large:
        // 大图模式：大卡片，网格布局
        return Padding(
          padding: const EdgeInsets.all(12),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemCount: subs.length,
            itemBuilder: (_, i) =>
                _buildFolderCard(subs[i], scheme, folder, large: true),
          ),
        );
      case ViewMode.medium:
        // 中图模式：中等卡片，网格自适应换行
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.0,
            ),
            itemCount: subs.length,
            itemBuilder: (_, i) =>
                _buildFolderCard(subs[i], scheme, folder, large: false),
          ),
        );
      case ViewMode.list:
        // 列表模式：垂直列表
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: subs
                .map((s) => _buildFolderListItem(s, scheme, folder))
                .toList(),
          ),
        );
    }
  }

  Widget _buildFolderCard(SubFolderEntry s, ColorScheme scheme, String? folder,
      {required bool large}) {
    return GestureDetector(
      onTap: () {
        ref.read(currentFolderProvider.notifier).state = s.path;
        ref.read(_folderExpandStateProvider.notifier).update((state) {
          final newSet = Set<String>.from(state);
          newSet.add(folder ?? '');
          return newSet;
        });
        ref.read(selectionProvider.notifier).state = null;
      },
      child: Container(
        width: large ? double.infinity : 160,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder, size: large ? 36 : 26, color: scheme.primary),
            SizedBox(height: large ? 8 : 4),
            Text(s.name,
                style: TextStyle(
                    fontSize: large ? 12 : 11, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
                maxLines: 1),
            const SizedBox(height: 1),
            Text('${s.fileCount} 张',
                style: TextStyle(
                    fontSize: large ? 10 : 9,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderListItem(
      SubFolderEntry s, ColorScheme scheme, String? folder) {
    return GestureDetector(
      onTap: () {
        ref.read(currentFolderProvider.notifier).state = s.path;
        ref.read(_folderExpandStateProvider.notifier).update((state) {
          final newSet = Set<String>.from(state);
          newSet.add(folder ?? '');
          return newSet;
        });
        ref.read(selectionProvider.notifier).state = null;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.folder, size: 20, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(s.name, style: const TextStyle(fontSize: 13)),
            ),
            Text('${s.fileCount} 张',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : Colors.black54)),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 18, color: scheme.outline),
          ],
        ),
      ),
    );
  }

  void _showPathInput(BuildContext context) async {
    final currentPath = ref.read(currentFolderProvider);
    final controller = TextEditingController(text: currentPath ?? '');
    final newPath = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('跳转到文件夹'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: '输入文件夹完整路径',
            prefixIcon: const Icon(Icons.folder_open),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final p = controller.text.trim();
              Navigator.pop(context, p.isNotEmpty ? p : null);
            },
            child: const Text('跳转'),
          ),
        ],
      ),
    );
    if (newPath != null && mounted) {
      ref.read(currentFolderProvider.notifier).state = newPath;
      // 展开所有祖先节点
      var parent = Directory(newPath).parent.path;
      while (parent.isNotEmpty) {
        ref.read(_folderExpandStateProvider.notifier).update((state) {
          final newSet = Set<String>.from(state)..add(parent);
          return newSet;
        });
        final grandParent = Directory(parent).parent.path;
        if (grandParent == parent) break;
        parent = grandParent;
      }
      ref.read(selectionProvider.notifier).state = null;
    }
  }
}

// ─────────────────────────────────────────────
// 媒体容器（按 viewMode 切换：大图 / 中图 / 列表 / 时间轴）
// ─────────────────────────────────────────────

class _MediaContainer extends ConsumerWidget {
  final ViewMode mode;
  const _MediaContainer({super.key, required this.mode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final browserMode = ref.watch(browserModeProvider);
    // 时间轴模式：套一层时间轴侧栏
    if (browserMode == BrowserMode.timeline) {
      return _TimelineScaffold(child: _viewFor(mode));
    }
    // 文件夹模式：套路径栏 + 子目录
    if (browserMode == BrowserMode.folder) {
      return _FolderModeContent(viewWidget: _viewFor(mode));
    }
    return _viewFor(mode);
  }

  Widget _viewFor(ViewMode mode) {
    switch (mode) {
      case ViewMode.large:
        return const _MediaLargeGrid();
      case ViewMode.medium:
        return const _MediaMediumGrid();
      case ViewMode.list:
        return const _MediaList();
    }
  }
}

/// 大图模式：MasonryGridView 3 列
class _MediaLargeGrid extends ConsumerStatefulWidget {
  const _MediaLargeGrid();
  @override
  ConsumerState<_MediaLargeGrid> createState() => _MediaLargeGridState();
}

class _MediaLargeGridState extends ConsumerState<_MediaLargeGrid> {
  final _scroll = ScrollController();
  // 每个 item 的 GlobalKey（按 mediaId 缓存，保证 build 间稳定）
  final Map<int, GlobalKey> _keyCache = {};
  String? _lastReportedBucket;
  // 拖选状态
  Offset? _dragStart;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    // 所有对 provider 的修改都必须延后到 build 之后，
    // 否则会触发 Riverpod 的 "modify provider while building" 错误。
    // 下一帧 addPostFrameCallback 已经是 frame 之后，listener 不会处于 build 中。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(timelineLinkProvider.notifier).clearBucketKeys();
      ref.read(timelineLinkProvider.notifier).attachScroll(_scroll);
    });
  }

  @override
  void dispose() {
    // dispose 里**禁止**直接改 provider（属于 widget 生命周期，会被
    // debugCanModifyProviders 检测到并抛错）。由下一次 initState 的
    // addPostFrameCallback 统一清掉即可。
    _scroll.dispose();
    super.dispose();
  }

  GlobalKey _keyOf(MediaItem m) =>
      _keyCache.putIfAbsent(m.id, () => GlobalKey());

  @override
  Widget build(BuildContext context) {
    final asyncMedia = ref.watch(browserMediaProvider);
    final selection = ref.watch(selectionProvider);
    final inMulti = selection != null;
    return asyncMedia.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败', maxLines: 2, overflow: TextOverflow.ellipsis)),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('没有可显示的媒体，点击右上角"导入"开始'));
        }
        // 找每个 bucket 的首项
        final firstOfBucket = <String>{};
        for (final m in items) {
          firstOfBucket.add(_bucketKeyOf(m));
        }
        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollEndNotification) {
              _reportActiveBucket(items);
            }
            return false;
          },
          child: Listener(
            onPointerDown: (e) {
              if (inMulti) {
                _dragStart = e.position;
                _isDragging = false;
                // 立即把按下点命中的项加入选择（避免快速拖动时 onTap 来不及触发，
                // 造成"明明点在 A 上、最后却选中了 B"）
                final gridBox = context.findRenderObject() as RenderBox?;
                if (gridBox != null) {
                  final hit =
                      _hitTestMediaItem(e.position, gridBox, items, _keyCache);
                  if (hit != null) {
                    final cur = ref.read(selectionProvider);
                    if (cur == null) {
                      ref.read(selectionProvider.notifier).state = {
                        hit.item.id
                      };
                    } else if (!cur.contains(hit.item.id)) {
                      ref.read(selectionProvider.notifier).state = {
                        ...cur,
                        hit.item.id
                      };
                    }
                  }
                }
              }
            },
            onPointerMove: (e) {
              if (!inMulti || _dragStart == null) return;
              if (!_isDragging) {
                if ((e.position - _dragStart!).distance < 5) return;
                setState(() => _isDragging = true);
              }
              final gridBox = context.findRenderObject() as RenderBox?;
              if (gridBox == null) return;
              final hit =
                  _hitTestMediaItem(e.position, gridBox, items, _keyCache);
              if (hit == null) return;
              final cur = ref.read(selectionProvider);
              if (cur == null) {
                ref.read(selectionProvider.notifier).state = {hit.item.id};
              } else if (cur.contains(hit.item.id)) {
                // 拖选时：命中已选项 → 取消；命中未选项 → 选中（toggle 行为）
                final next = {...cur}..remove(hit.item.id);
                ref.read(selectionProvider.notifier).state =
                    next.isEmpty ? null : next;
              } else {
                ref.read(selectionProvider.notifier).state = {
                  ...cur,
                  hit.item.id
                };
              }
            },
            onPointerUp: (_) {
              if (_isDragging) {
                setState(() {
                  _dragStart = null;
                  _isDragging = false;
                });
              } else {
                _dragStart = null;
              }
            },
            onPointerCancel: (_) {
              _dragStart = null;
              if (_isDragging) {
                setState(() => _isDragging = false);
              }
            },
            child: MasonryGridView.count(
              controller: _scroll,
              physics:
                  _isDragging ? const NeverScrollableScrollPhysics() : null,
              crossAxisCount: 3,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              padding: const EdgeInsets.all(8),
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final meta = items[i];
                final bucket = _bucketKeyOf(meta);
                final key = _keyOf(meta.item);
                final isFirst = firstOfBucket.contains(bucket) &&
                    _bucketKeyOf(items[i == 0 ? 0 : i - 1]) != bucket;
                return KeyedSubtree(
                  key: key,
                  child: isFirst
                      ? _BucketAnchor(
                          bucket: bucket,
                          child: _RightClickMenu(
                            meta: meta,
                            child: MediaGridItem(
                              meta: meta,
                              selected:
                                  selection?.contains(meta.item.id) ?? false,
                              multiSelect: inMulti,
                            ),
                          ),
                        )
                      : _RightClickMenu(
                          meta: meta,
                          child: MediaGridItem(
                            meta: meta,
                            selected:
                                selection?.contains(meta.item.id) ?? false,
                            multiSelect: inMulti,
                          ),
                        ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// 滚动停止后，找出"最靠近视口顶部的可见项"，更新激活 bucket
  /// 顺序遍历 items，找到第一个 top 已经越过 viewport 顶的（带 -8px 容差）即返回。
  /// 大多数情况会在前 1~2 个可见行就命中。
  void _reportActiveBucket(List<MediaItemWithMeta> items) {
    if (items.isEmpty) return;
    final scrollableCtx = _scroll.position.context.notificationContext;
    final viewport = scrollableCtx?.findRenderObject() as RenderBox?;
    if (viewport == null) return;
    final viewportTop = viewport.localToGlobal(Offset.zero).dy;

    String? bestBucket;
    for (int i = 0; i < items.length; i++) {
      final m = items[i];
      final key = _keyCache[m.item.id];
      final ro = key?.currentContext?.findRenderObject() as RenderBox?;
      if (ro == null || !ro.attached) continue;
      final itemTop = ro.localToGlobal(Offset.zero).dy;
      final delta = itemTop - viewportTop;
      if (delta >= -8) {
        bestBucket = _bucketKeyOf(m);
        break; // 第一个 top 越过视口顶的项就是激活 bucket
      }
    }
    bestBucket ??= _bucketKeyOf(items.last);
    if (bestBucket != _lastReportedBucket) {
      _lastReportedBucket = bestBucket;
      ref.read(activeTimelineBucketProvider.notifier).state = bestBucket;
    }
  }
}

/// 中图模式：单行更窄，缩略图 + 底部信息（文件名 / 时间 / 标签）
class _MediaMediumGrid extends ConsumerStatefulWidget {
  const _MediaMediumGrid();
  @override
  ConsumerState<_MediaMediumGrid> createState() => _MediaMediumGridState();
}

class _MediaMediumGridState extends ConsumerState<_MediaMediumGrid> {
  final _scroll = ScrollController();
  final Map<int, GlobalKey> _keyCache = {};
  String? _lastReportedBucket;
  // 拖选状态
  Offset? _dragStart;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    // 所有对 provider 的修改都必须延后到 build 之后，
    // 否则会触发 Riverpod 的 "modify provider while building" 错误。
    // 下一帧 addPostFrameCallback 已经是 frame 之后，listener 不会处于 build 中。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(timelineLinkProvider.notifier).clearBucketKeys();
      ref.read(timelineLinkProvider.notifier).attachScroll(_scroll);
    });
  }

  @override
  void dispose() {
    // dispose 里**禁止**直接改 provider（属于 widget 生命周期，会被
    // debugCanModifyProviders 检测到并抛错）。由下一次 initState 的
    // addPostFrameCallback 统一清掉即可。
    _scroll.dispose();
    super.dispose();
  }

  GlobalKey _keyOf(MediaItem m) =>
      _keyCache.putIfAbsent(m.id, () => GlobalKey());

  @override
  Widget build(BuildContext context) {
    final asyncMedia = ref.watch(browserMediaProvider);
    final selection = ref.watch(selectionProvider);
    final inMulti = selection != null;
    return asyncMedia.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败', maxLines: 2, overflow: TextOverflow.ellipsis)),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('没有可显示的媒体'));
        }
        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollEndNotification) {
              _reportActiveBucket(items);
            }
            return false;
          },
          child: Listener(
            onPointerDown: (e) {
              if (inMulti) {
                _dragStart = e.position;
                _isDragging = false;
                // 立即把按下点命中的项加入选择（避免快速拖动时 onTap 来不及触发，
                // 造成"明明点在 A 上、最后却选中了 B"）
                final gridBox = context.findRenderObject() as RenderBox?;
                if (gridBox != null) {
                  final hit =
                      _hitTestMediaItem(e.position, gridBox, items, _keyCache);
                  if (hit != null) {
                    final cur = ref.read(selectionProvider);
                    if (cur == null) {
                      ref.read(selectionProvider.notifier).state = {
                        hit.item.id
                      };
                    } else if (!cur.contains(hit.item.id)) {
                      ref.read(selectionProvider.notifier).state = {
                        ...cur,
                        hit.item.id
                      };
                    }
                  }
                }
              }
            },
            onPointerMove: (e) {
              if (!inMulti || _dragStart == null) return;
              if (!_isDragging) {
                if ((e.position - _dragStart!).distance < 5) return;
                setState(() => _isDragging = true);
              }
              final gridBox = context.findRenderObject() as RenderBox?;
              if (gridBox == null) return;
              final hit =
                  _hitTestMediaItem(e.position, gridBox, items, _keyCache);
              if (hit == null) return;
              final cur = ref.read(selectionProvider);
              if (cur == null) {
                ref.read(selectionProvider.notifier).state = {hit.item.id};
              } else if (cur.contains(hit.item.id)) {
                // 拖选时：命中已选项 → 取消；命中未选项 → 选中（toggle 行为）
                final next = {...cur}..remove(hit.item.id);
                ref.read(selectionProvider.notifier).state =
                    next.isEmpty ? null : next;
              } else {
                ref.read(selectionProvider.notifier).state = {
                  ...cur,
                  hit.item.id
                };
              }
            },
            onPointerUp: (_) {
              if (_isDragging) {
                setState(() {
                  _dragStart = null;
                  _isDragging = false;
                });
              } else {
                _dragStart = null;
              }
            },
            onPointerCancel: (_) {
              _dragStart = null;
              if (_isDragging) {
                setState(() => _isDragging = false);
              }
            },
            child: GridView.builder(
              controller: _scroll,
              physics:
                  _isDragging ? const NeverScrollableScrollPhysics() : null,
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.78,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: items.length,
              itemBuilder: (ctx, i) {
                final meta = items[i];
                final bucket = _bucketKeyOf(meta);
                final key = _keyOf(meta.item);
                final isFirst = i == 0 || _bucketKeyOf(items[i - 1]) != bucket;
                return KeyedSubtree(
                  key: key,
                  child: isFirst
                      ? _BucketAnchor(
                          bucket: bucket,
                          child: _RightClickMenu(
                            meta: meta,
                            child: _MediumCard(
                              meta: meta,
                              selected:
                                  selection?.contains(meta.item.id) ?? false,
                              multiSelect: inMulti,
                            ),
                          ),
                        )
                      : _RightClickMenu(
                          meta: meta,
                          child: _MediumCard(
                            meta: meta,
                            selected:
                                selection?.contains(meta.item.id) ?? false,
                            multiSelect: inMulti,
                          ),
                        ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _reportActiveBucket(List<MediaItemWithMeta> items) {
    if (items.isEmpty) return;
    final scrollableCtx = _scroll.position.context.notificationContext;
    final viewport = scrollableCtx?.findRenderObject() as RenderBox?;
    if (viewport == null) return;
    final viewportTop = viewport.localToGlobal(Offset.zero).dy;

    String? bestBucket;
    for (int i = 0; i < items.length; i++) {
      final m = items[i];
      final key = _keyCache[m.item.id];
      final ro = key?.currentContext?.findRenderObject() as RenderBox?;
      if (ro == null || !ro.attached) continue;
      final itemTop = ro.localToGlobal(Offset.zero).dy;
      final delta = itemTop - viewportTop;
      if (delta >= -8) {
        bestBucket = _bucketKeyOf(m);
        break;
      }
    }
    bestBucket ??= _bucketKeyOf(items.last);
    if (bestBucket != _lastReportedBucket) {
      _lastReportedBucket = bestBucket;
      ref.read(activeTimelineBucketProvider.notifier).state = bestBucket;
    }
  }
}

/// 列表模式：横向滑动 DataTable 风格
class _MediaList extends ConsumerStatefulWidget {
  const _MediaList();
  @override
  ConsumerState<_MediaList> createState() => _MediaListState();
}

class _MediaListState extends ConsumerState<_MediaList> {
  final _scroll = ScrollController();
  final Map<int, GlobalKey> _keyCache = {};
  String? _lastReportedBucket;
  // 拖选状态
  Offset? _dragStart;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    // 所有对 provider 的修改都必须延后到 build 之后，
    // 否则会触发 Riverpod 的 "modify provider while building" 错误。
    // 下一帧 addPostFrameCallback 已经是 frame 之后，listener 不会处于 build 中。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(timelineLinkProvider.notifier).clearBucketKeys();
      ref.read(timelineLinkProvider.notifier).attachScroll(_scroll);
    });
  }

  @override
  void dispose() {
    // dispose 里**禁止**直接改 provider（属于 widget 生命周期，会被
    // debugCanModifyProviders 检测到并抛错）。由下一次 initState 的
    // addPostFrameCallback 统一清掉即可。
    _scroll.dispose();
    super.dispose();
  }

  GlobalKey _keyOf(MediaItem m) =>
      _keyCache.putIfAbsent(m.id, () => GlobalKey());

  @override
  Widget build(BuildContext context) {
    final asyncMedia = ref.watch(browserMediaProvider);
    final selection = ref.watch(selectionProvider);
    final inMulti = selection != null;
    return asyncMedia.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败', maxLines: 2, overflow: TextOverflow.ellipsis)),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('没有可显示的媒体'));
        }
        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollEndNotification) {
              _reportActiveBucket(items);
            }
            return false;
          },
          child: Listener(
            onPointerDown: (e) {
              if (inMulti) {
                _dragStart = e.position;
                _isDragging = false;
                // 立即把按下点命中的项加入选择（避免快速拖动时 onTap 来不及触发，
                // 造成"明明点在 A 上、最后却选中了 B"）
                final gridBox = context.findRenderObject() as RenderBox?;
                if (gridBox != null) {
                  final hit =
                      _hitTestMediaItem(e.position, gridBox, items, _keyCache);
                  if (hit != null) {
                    final cur = ref.read(selectionProvider);
                    if (cur == null) {
                      ref.read(selectionProvider.notifier).state = {
                        hit.item.id
                      };
                    } else if (!cur.contains(hit.item.id)) {
                      ref.read(selectionProvider.notifier).state = {
                        ...cur,
                        hit.item.id
                      };
                    }
                  }
                }
              }
            },
            onPointerMove: (e) {
              if (!inMulti || _dragStart == null) return;
              if (!_isDragging) {
                if ((e.position - _dragStart!).distance < 5) return;
                setState(() => _isDragging = true);
              }
              final gridBox = context.findRenderObject() as RenderBox?;
              if (gridBox == null) return;
              final hit =
                  _hitTestMediaItem(e.position, gridBox, items, _keyCache);
              if (hit == null) return;
              final cur = ref.read(selectionProvider);
              if (cur == null) {
                ref.read(selectionProvider.notifier).state = {hit.item.id};
              } else if (cur.contains(hit.item.id)) {
                // 拖选时：命中已选项 → 取消；命中未选项 → 选中（toggle 行为）
                final next = {...cur}..remove(hit.item.id);
                ref.read(selectionProvider.notifier).state =
                    next.isEmpty ? null : next;
              } else {
                ref.read(selectionProvider.notifier).state = {
                  ...cur,
                  hit.item.id
                };
              }
            },
            onPointerUp: (_) {
              if (_isDragging) {
                setState(() {
                  _dragStart = null;
                  _isDragging = false;
                });
              } else {
                _dragStart = null;
              }
            },
            onPointerCancel: (_) {
              _dragStart = null;
              if (_isDragging) {
                setState(() => _isDragging = false);
              }
            },
            child: ListView.separated(
              controller: _scroll,
              physics:
                  _isDragging ? const NeverScrollableScrollPhysics() : null,
              padding: const EdgeInsets.all(8),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final meta = items[i];
                final bucket = _bucketKeyOf(meta);
                final key = _keyOf(meta.item);
                final isFirst = i == 0 || _bucketKeyOf(items[i - 1]) != bucket;
                return KeyedSubtree(
                  key: key,
                  child: isFirst
                      ? _BucketAnchor(
                          bucket: bucket,
                          child: _RightClickMenu(
                            meta: meta,
                            child: _ListRow(
                              meta: meta,
                              selected:
                                  selection?.contains(meta.item.id) ?? false,
                              multiSelect: inMulti,
                            ),
                          ),
                        )
                      : _RightClickMenu(
                          meta: meta,
                          child: _ListRow(
                            meta: meta,
                            selected:
                                selection?.contains(meta.item.id) ?? false,
                            multiSelect: inMulti,
                          ),
                        ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _reportActiveBucket(List<MediaItemWithMeta> items) {
    if (items.isEmpty) return;
    final scrollableCtx = _scroll.position.context.notificationContext;
    final viewport = scrollableCtx?.findRenderObject() as RenderBox?;
    if (viewport == null) return;
    final viewportTop = viewport.localToGlobal(Offset.zero).dy;

    String? bestBucket;
    for (int i = 0; i < items.length; i++) {
      final m = items[i];
      final key = _keyCache[m.item.id];
      final ro = key?.currentContext?.findRenderObject() as RenderBox?;
      if (ro == null || !ro.attached) continue;
      final itemTop = ro.localToGlobal(Offset.zero).dy;
      final delta = itemTop - viewportTop;
      if (delta >= -8) {
        bestBucket = _bucketKeyOf(m);
        break;
      }
    }
    bestBucket ??= _bucketKeyOf(items.last);
    if (bestBucket != _lastReportedBucket) {
      _lastReportedBucket = bestBucket;
      ref.read(activeTimelineBucketProvider.notifier).state = bestBucket;
    }
  }
}

// ─────────────────────────────────────────────
// 时间轴侧栏（按年/月聚合右侧时间节点）
// ─────────────────────────────────────────────

/// 时间轴"图片创建时间"统一来源：
///  EXIF DateTimeOriginal > 磁盘 mtime > 归档时间
DateTime _timelineTimeOf(MediaItemWithMeta m) {
  final exifTaken = m.exif?.dateTaken;
  if (exifTaken != null) return exifTaken;
  final mtime = m.item.fileModifiedAt;
  if (mtime != null) return mtime;
  return m.item.indexedAt;
}

/// 时间轴桶 key（"YYYY-MM"），按图片"创建时间"分桶
String _bucketKeyOf(MediaItemWithMeta m) {
  final d = _timelineTimeOf(m);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}';
}

class _TimelineScaffold extends ConsumerStatefulWidget {
  final Widget child;
  const _TimelineScaffold({required this.child});
  @override
  ConsumerState<_TimelineScaffold> createState() => _TimelineScaffoldState();
}

class _TimelineScaffoldState extends ConsumerState<_TimelineScaffold> {
  // 仅用于右侧 bucket 列表自身的滚动
  final _sidebarScroll = ScrollController();

  @override
  void dispose() {
    _sidebarScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 从 MediaDateIndexes 表获取月度桶数据（不依赖全量媒体加载）
    final bucketsAsync = ref.watch(timelineBucketsProvider);
    // 联动：监听"激活桶"——图片网格滚动时自动更新
    final activeBucket = ref.watch(activeTimelineBucketProvider);

    // 仍然从 browserMediaProvider 获取排序后的全量列表用于计算
    // bucketFirstIndex（给点击跳转的 offset 估算使用）
    final asyncMedia = ref.watch(browserMediaProvider);

    return bucketsAsync.when(
      loading: () => asyncMedia.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) => _buildWithMedia(items, activeBucket),
      ),
      error: (e, _) => Center(child: Text('$e')),
      data: (buckets) => _buildWithBuckets(buckets, activeBucket, asyncMedia),
    );
  }

  /// 使用 MediaDateIndexes 表的桶数据构建侧边栏
  Widget _buildWithBuckets(
    List<MonthlyBucket> buckets,
    String? activeBucket,
    AsyncValue<List<MediaItemWithMeta>> asyncMedia,
  ) {
    if (buckets.isEmpty) return widget.child;

    // 仍然从媒体列表计算 bucketFirstIndex（供点击跳转估算 offset 使用）
    asyncMedia.whenData((items) {
      if (items.isEmpty) return;
      final sorted = [...items]..sort((a, b) {
          final ad = _timelineTimeOf(a);
          final bd = _timelineTimeOf(b);
          return bd.compareTo(ad);
        });
      final firstIndex = <String, int>{};
      for (int i = 0; i < sorted.length; i++) {
        firstIndex.putIfAbsent(_bucketKeyOf(sorted[i]), () => i);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(timelineLinkProvider.notifier).setBucketLayout(
              bucketFirstIndex: Map<String, int>.from(firstIndex),
              totalItemCount: sorted.length,
            );
      });
    });

    return Row(
      children: [
        Expanded(child: widget.child),
        _buildSidebar(buckets, activeBucket),
      ],
    );
  }

  /// 回退：当桶数据不可用时，从全量媒体列表构建
  Widget _buildWithMedia(List<MediaItemWithMeta> items, String? activeBucket) {
    if (items.isEmpty) return widget.child;
    // 时间轴：图片本身的"创建时间"——
    // 优先级：EXIF DateTimeOriginal > 磁盘 mtime > 归档时间
    final sorted = [...items]..sort((a, b) {
        final ad = _timelineTimeOf(a);
        final bd = _timelineTimeOf(b);
        return bd.compareTo(ad);
      });
    // 桶 = "YYYY-MM" 段
    final buckets = <String, int>{};
    // 桶 → 该桶在 sorted 数组中首项下标（用于点击右侧时间轴时估算 offset）
    final firstIndex = <String, int>{};
    for (int i = 0; i < sorted.length; i++) {
      final m = sorted[i];
      final key = _bucketKeyOf(m);
      buckets[key] = (buckets[key] ?? 0) + 1;
      firstIndex.putIfAbsent(key, () => i);
    }
    // 把"桶 → 首项 index + 总数"同步给 provider，供点击跳转用
    // （必须延后到 build 之外以避免 Riverpod 的 build 阶段告警）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(timelineLinkProvider.notifier).setBucketLayout(
            bucketFirstIndex: Map<String, int>.from(firstIndex),
            totalItemCount: sorted.length,
          );
    });
    final bucketList = buckets.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Row(
      children: [
        Expanded(child: widget.child),
        _buildSidebarFromMap(bucketList, buckets, activeBucket),
      ],
    );
  }

  /// 从 MonthlyBucket 列表构建侧边栏 UI（已废弃，由左侧 _TimelineBucketList 替代）
  Widget _buildSidebar(List<MonthlyBucket> buckets, String? activeBucket) {
    return const SizedBox.shrink();
  }

  /// 从 Map 构建侧边栏 UI（回退路径，已废弃）
  Widget _buildSidebarFromMap(
      List<String> bucketList, Map<String, int> buckets, String? activeBucket) {
    return const SizedBox.shrink();
  }

  /// 点击 bucket 时的处理（两阶段跳转，解决 GridView lazy build 导致
  /// 远端 bucket 的 GlobalKey 还没注册的问题）：
  ///
  /// 1) 立即更新 activeTimelineBucketProvider（UI 高亮）
  /// 2) 如果该 bucket 的 GlobalKey 已注册 → Scrollable.ensureVisible 精确跳
  /// 3) 否则：
  ///    a) 用 bucketFirstIndex / totalItemCount 估算目标 offset
  ///    b) scrollController.jumpTo 强制 GridView build 该区域
  ///    c) 下一帧 addPostFrameCallback 再尝试 ensureVisible 精确跳
  /// 4) 仍然没注册时（极端情况）保持当前 offset，不再乱跳
  void _onBucketTap(String bucket) {
    ref.read(activeTimelineBucketProvider.notifier).state = bucket;
    final link = ref.read(timelineLinkProvider);

    // 阶段 1：已注册 → 直接精确跳
    final ctx = link.bucketKeys[bucket]?.currentContext;
    if (ctx != null) {
      _smoothScrollTo(ctx);
      return;
    }

    // 阶段 2：未注册 → 估算 offset 强制 build
    final scroll = link.scrollController;
    if (scroll == null || !scroll.hasClients) return;
    final pos = scroll.position;
    final total = link.totalItemCount;
    final firstIdx = link.bucketFirstIndex[bucket];
    if (total == 0 || firstIdx == null) return;

    // 用 maxScrollExtent / total 估算平均 item 高度（瀑布流粗略即可）
    final avgItemH = pos.maxScrollExtent > 0 && pos.maxScrollExtent.isFinite
        ? (pos.maxScrollExtent / total).clamp(60.0, 600.0)
        : 200.0;
    final target = (firstIdx * avgItemH).clamp(0.0, pos.maxScrollExtent);
    // 用 jumpTo（瞬时）而不是 animateTo，避免和后续 ensureVisible 抢动画
    scroll.jumpTo(target);

    // 阶段 3：等下一帧 build 完再精确跳；最多重试 5 帧
    int retries = 0;
    void tryPreciseScroll(Duration _) {
      if (!mounted) return;
      final newCtx =
          ref.read(timelineLinkProvider).bucketKeys[bucket]?.currentContext;
      if (newCtx != null) {
        _smoothScrollTo(newCtx);
        return;
      }
      if (++retries < 5) {
        WidgetsBinding.instance.addPostFrameCallback(tryPreciseScroll);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback(tryPreciseScroll);
  }

  /// 实际执行 Scrollable.ensureVisible：
  /// - keepVisibleAtStart 让 item 出现在视口内即停，自动选最小滚动距离，
  ///   不会像 explicit(0.0) 那样强制把 item 顶到视口顶部导致跳得太远
  /// - 当前 bucket 已在可见区时则不滚动，体感最自然
  void _smoothScrollTo(BuildContext ctx) {
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.0,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    );
  }
}

/// 给"桶内第一项"打的 GlobalKey 包装器
/// - initState 后把 bucket -> key 注册到 timelineLinkProvider
/// - 同一 bucket 多次构建时只保留第一次的 key（item 在数据更新时换位置不影响）
class _BucketAnchor extends ConsumerStatefulWidget {
  final String bucket;
  final Widget child;
  const _BucketAnchor({required this.bucket, required this.child});

  @override
  ConsumerState<_BucketAnchor> createState() => _BucketAnchorState();
}

class _BucketAnchorState extends ConsumerState<_BucketAnchor> {
  final _key = GlobalKey();
  String? _registeredBucket;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryRegister());
  }

  @override
  void didUpdateWidget(covariant _BucketAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bucket != widget.bucket) {
      _registeredBucket = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryRegister());
    }
  }

  void _tryRegister() {
    if (!mounted) return;
    if (_registeredBucket == widget.bucket) return;
    final link = ref.read(timelineLinkProvider);
    if (link.bucketKeys[widget.bucket] == null) {
      ref
          .read(timelineLinkProvider.notifier)
          .registerBucketKey(widget.bucket, _key);
      _registeredBucket = widget.bucket;
    } else {
      // 已经有首项的 key 了，自己不是首项
      _registeredBucket = widget.bucket;
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _key,
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────
// 中图模式卡片
// ─────────────────────────────────────────────

class _MediumCard extends ConsumerWidget {
  final MediaItemWithMeta meta;
  final bool selected;
  final bool multiSelect;
  const _MediumCard({
    required this.meta,
    required this.selected,
    required this.multiSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = _timelineTimeOf(meta);
    final dateText =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Colors.black.withOpacity(0.04),
          width: selected ? 2.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: PixelThumb(
                    item: meta.item,
                    hot: () => true, // 中图模式没有热区优化
                  ),
                ),
                if (meta.item.isMissing)
                  const Positioned(
                    top: 4,
                    left: 4,
                    child: _MissingBadge(),
                  ),
                if (selected || multiSelect)
                  const Positioned(top: 4, right: 4, child: _SelectBadge()),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
            child: SizedBox(
              height: 44,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    p.basename(meta.item.filePath),
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(dateText,
                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  if (meta.tags.isNotEmpty)
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Wrap(
                          spacing: 3,
                          runSpacing: 2,
                          children: meta.tags
                              .take(3)
                              .map((t) => _TagChipInline(tag: t))
                              .toList(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 列表模式行
// ─────────────────────────────────────────────

class _ListRow extends ConsumerWidget {
  final MediaItemWithMeta meta;
  final bool selected;
  final bool multiSelect;
  const _ListRow({
    required this.meta,
    required this.selected,
    required this.multiSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exif = meta.exif;
    final date = _timelineTimeOf(meta);
    final dateText =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return Container(
      decoration: BoxDecoration(
        color: selected
            ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          // 缩略图（使用统一 PixelThumb，列表模式没有热区）
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              children: [
                Positioned.fill(
                  child: PixelThumb(
                    item: meta.item,
                    hot: () => true,
                  ),
                ),
                if (meta.item.isMissing)
                  const Positioned(
                      top: 0, left: 0, child: _MissingBadge(small: true)),
                if (selected || multiSelect)
                  const Positioned(
                      top: 0, right: 0, child: _SelectBadge(small: true)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // 信息列
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.basename(meta.item.filePath),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  meta.item.filePath,
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    _formatSize(meta.item.fileSizeBytes),
                    dateText,
                    if (exif?.model != null && exif!.model!.isNotEmpty)
                      exif.model!,
                  ].join(' • '),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (meta.tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Wrap(
                      spacing: 4,
                      children:
                          meta.tags.map((t) => _TagChipInline(tag: t)).toList(),
                    ),
                  ),
              ],
            ),
          ),
          // 右侧 EXIF 摘要
          SizedBox(
            width: 180,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Text(
                [
                  if (exif != null) ...[
                    if (exif.fNumber != null) 'f/${exif.fNumber}',
                    if (exif.exposureTime != null) '${exif.exposureTime}s',
                    if (exif.isoSpeed != null) 'ISO${exif.isoSpeed}',
                    if (exif.focalLength != null) '${exif.focalLength}mm',
                    if (exif.cityName != null && exif.cityName!.isNotEmpty)
                      exif.cityName!,
                  ],
                ].join('  •  '),
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatSize(int? bytes) {
    if (bytes == null) return '-';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}

// ─────────────────────────────────────────────
// 公共小组件：缩略图 / 角标 / 标签 chip
// ─────────────────────────────────────────────
// _ThumbnailImage 已被 PixelThumb 统一替换（widget_pixel_thumb.dart），
// 保留此处仅作兼容性兜底：如未来有代码仍然引用 _ThumbnailImage，
// 直接代理到 PixelThumb。
// 实际上当前文件已无 _ThumbnailImage 调用方，可安全删除。
// （如要彻底删除，移除本 class 即可。）

class _MissingBadge extends StatelessWidget {
  final bool small;
  const _MissingBadge({this.small = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(small ? 2 : 3),
        decoration: const BoxDecoration(
          color: Colors.orange,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.warning_amber,
            size: small ? 10 : 14, color: Colors.white),
      );
}

class _SelectBadge extends StatelessWidget {
  final bool small;
  const _SelectBadge({this.small = false});
  @override
  Widget build(BuildContext context) => Container(
        width: small ? 16 : 22,
        height: small ? 16 : 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.primary,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Icon(Icons.check, size: small ? 10 : 14, color: Colors.white),
      );
}

class _TagChipInline extends StatelessWidget {
  final Tag tag;
  const _TagChipInline({required this.tag});
  @override
  Widget build(BuildContext context) {
    final color = _hex(tag.color) ?? Colors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(tag.name,
          style: TextStyle(
              fontSize: 9, color: color, fontWeight: FontWeight.w500)),
    );
  }
}

class _RightClickMenu extends ConsumerStatefulWidget {
  final MediaItemWithMeta meta;
  final Widget child;
  const _RightClickMenu({required this.meta, required this.child});

  @override
  ConsumerState<_RightClickMenu> createState() => _RightClickMenuState();
}

class _RightClickMenuState extends ConsumerState<_RightClickMenu> {
  @override
  Widget build(BuildContext context) {
    final meta = widget.meta;
    final inMulti = ref.watch(selectionProvider) != null;
    final isSelected =
        ref.watch(selectionProvider)?.contains(meta.item.id) ?? false;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (inMulti) {
          final sel = ref.read(selectionProvider)!;
          final next = {...sel};
          if (next.contains(meta.item.id)) {
            next.remove(meta.item.id);
          } else {
            next.add(meta.item.id);
          }
          ref.read(selectionProvider.notifier).state =
              next.isEmpty ? null : next;
        } else {
          showDialog(
            context: context,
            builder: (_) => _MediaDetailDialogInline(meta: meta),
          );
        }
      },
      onLongPress: () {
        if (!inMulti) {
          ref.read(selectionProvider.notifier).state = {meta.item.id};
          HapticFeedback.selectionClick();
        }
      },
      onSecondaryTapDown: (details) {
        // 右键前自动选中自己（多选模式下也是"加入/移出"由位置决定时再覆盖）
        if (!inMulti) {
          ref.read(selectionProvider.notifier).state = {meta.item.id};
        } else {
          final sel = ref.read(selectionProvider)!;
          if (!sel.contains(meta.item.id)) {
            final next = {...sel, meta.item.id};
            ref.read(selectionProvider.notifier).state = next;
          }
        }
        _showContextMenu(
          context,
          ref,
          meta,
          Offset(details.globalPosition.dx, details.globalPosition.dy),
        );
      },
      child: Stack(
        children: [
          widget.child,
          // 选中状态在右键时立即显示
          if (isSelected)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showContextMenu(BuildContext context, WidgetRef ref,
      MediaItemWithMeta meta, Offset position) async {
    final selection = ref.read(selectionProvider);
    final inMulti = selection != null && selection.length > 1;
    // 多选时若右键项尚未包含在选区，则只对当前右键项操作
    final isRightClickedInSelection =
        selection?.contains(meta.item.id) ?? false;

    final db = ref.read(databaseProvider);
    // 多选且右键命中项属于选区 → 操作整个选区；否则只操作右键项
    final List<MediaItem> targetItems;
    if (inMulti && isRightClickedInSelection) {
      final rows = await (db.select(db.mediaItems)
            ..where((t) => t.id.isIn(selection.toList())))
          .get();
      targetItems = rows;
    } else {
      targetItems = [meta.item];
    }
    final isMultiTarget = targetItems.length > 1;
    final missingCount = targetItems.where((it) => it.isMissing).length;

    final result = await showMenu<String>(
      context: context,
      // 关键：position 用 globalPosition - 右键实际坐标
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, 0),
      items: [
        PopupMenuItem<String>(
          value: 'open_detail',
          enabled: !isMultiTarget, // 多选时无法同时查看多个详情
          child: _MenuRow(
            icon: Icons.visibility_outlined,
            label: isMultiTarget ? '查看详情（多选时不可用）' : '查看详情',
            color: isMultiTarget ? Theme.of(context).disabledColor : null,
          ),
        ),
        PopupMenuItem<String>(
          value: 'add_tag',
          child: _MenuRow(
            icon: Icons.label_outline,
            label: isMultiTarget ? '批量添加/编辑标签' : '添加/编辑标签',
          ),
        ),
        if (missingCount > 0)
          PopupMenuItem<String>(
            value: 'add_tag',
            enabled: false,
            child: _MenuRow(
              icon: Icons.warning_amber,
              label: '其中 $missingCount 个文件已缺失，部分功能不可用',
              color: Colors.orange,
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'soft_delete',
          child: _MenuRow(
            icon: Icons.delete_outline,
            label: isMultiTarget ? '从归档移除（${targetItems.length} 项）' : '从归档移除',
            color: Colors.red,
          ),
        ),
      ],
    );
    if (result == null) return;
    switch (result) {
      case 'open_detail':
        if (isMultiTarget) return; // 防御：理论上不会触发
        showDialog(
            context: context,
            builder: (_) => _MediaDetailDialogInline(meta: meta));
        break;
      case 'add_tag':
        final saved = await showTagEditorDialog(context, items: targetItems);
        if (saved) {
          ref.read(browserRefreshSignalProvider.notifier).state++;
        }
        break;
      case 'soft_delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(isMultiTarget ? '批量移除' : '从归档移除？'),
            content: Text(isMultiTarget
                ? '将 ${targetItems.length} 个文件从数据库归档中移除（磁盘文件保留）。'
                : '${p.basename(meta.item.filePath)}（磁盘文件保留）'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('取消')),
              FilledButton.tonal(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('移除', style: TextStyle(color: Colors.red))),
            ],
          ),
        );
        if (ok == true) {
          await ref
              .read(databaseProvider)
              .softDeleteMedia(targetItems.map((it) => it.id).toList());
          ref.read(browserRefreshSignalProvider.notifier).state++;
        }
        break;
    }
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _MenuRow({required this.icon, required this.label, this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurface;
    return Row(children: [
      Icon(icon, size: 18, color: c),
      const SizedBox(width: 10),
      Expanded(
        child: Text(label,
            style: TextStyle(color: c), overflow: TextOverflow.ellipsis),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────
// 详情弹窗
// ─────────────────────────────────────────────

class _MediaDetailDialogInline extends StatefulWidget {
  final MediaItemWithMeta meta;
  const _MediaDetailDialogInline({required this.meta});

  @override
  State<_MediaDetailDialogInline> createState() =>
      _MediaDetailDialogInlineState();
}

class _MediaDetailDialogInlineState extends State<_MediaDetailDialogInline> {
  bool isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.pop(context),
      },
      child: Focus(
        autofocus: true,
        child: Consumer(builder: (context, ref, _) {
          return _DetailContent(
            meta: widget.meta,
            isExpanded: isExpanded,
            onToggleExpand: () => setState(() => isExpanded = !isExpanded),
          );
        }),
      ),
    );
  }
}

class _DetailContent extends ConsumerWidget {
  final MediaItemWithMeta meta;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  const _DetailContent({
    required this.meta,
    required this.isExpanded,
    required this.onToggleExpand,
  });

  Future<void> _openFolder(BuildContext context) async {
    final folderPath = p.dirname(meta.item.filePath);
    try {
      if (Platform.isWindows) {
        await Process.run('explorer', ['/select,', meta.item.filePath]);
      } else if (Platform.isLinux) {
        final result = await Process.run('xdg-open', [folderPath]);
        if (result.exitCode != 0) {
          final desktops = ['nautilus', 'dolphin', 'thunar', 'caja', 'pcmanfm'];
          for (final desktop in desktops) {
            final r = await Process.run('which', [desktop]);
            if (r.exitCode == 0) {
              await Process.run(desktop, [folderPath]);
              return;
            }
          }
        }
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-R', meta.item.filePath]);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法打开文件夹: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exif = meta.exif;
    final allMediaAsync = ref.watch(browserMediaProvider);
    final allMedia = allMediaAsync.valueOrNull ?? [];
    final currentIndex =
        allMedia.indexWhere((m) => m.item.filePath == meta.item.filePath);

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isExpanded ? 1400 : 760,
          maxHeight: isExpanded ? 900 : 640,
        ),
        child: Column(
          children: [
            AppBar(
              title: Text(p.basename(meta.item.filePath)),
              automaticallyImplyLeading: false,
              actions: [
                if (meta.item.isMissing)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Chip(
                      label: Text('文件已缺失',
                          style: TextStyle(fontSize: 11, color: Colors.white)),
                      backgroundColor: Colors.orange,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                IconButton(
                  tooltip: isExpanded ? '缩小' : '放大',
                  icon: Icon(
                      isExpanded ? Icons.fullscreen_exit : Icons.fullscreen),
                  onPressed: onToggleExpand,
                ),
                IconButton(
                  tooltip: '打开所在文件夹',
                  icon: const Icon(Icons.folder_open),
                  onPressed: () => _openFolder(context),
                ),
                IconButton(
                  tooltip: '编辑标签',
                  icon: const Icon(Icons.label_outline),
                  onPressed: () async {
                    await showTagEditorDialog(context, items: [meta.item]);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Expanded(
              child: Row(
                children: [
                  // ─── 左侧翻页按钮（在 Row 最左，不在图片 Stack 内） ───
                  if (currentIndex > 0)
                    _SideNavButton(
                      icon: Icons.chevron_left,
                      tooltip: '上一张',
                      onTap: () {
                        Navigator.pop(context);
                        showDialog(
                          context: context,
                          builder: (_) => _MediaDetailDialogInline(
                            meta: allMedia[currentIndex - 1],
                          ),
                        );
                      },
                    ),
                  // ─── 图片容器 + 底部居中的全屏按钮 ───
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF121212)
                            : const Color(0xFFF5F5F5),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // 图片本身（不再叠按钮）
                          meta.item.isMissing
                              ? const Icon(Icons.broken_image,
                                  color: Colors.white54, size: 80)
                              : (meta.item.fileType == 'image'
                                  ? GestureDetector(
                                      onTap: () {
                                        final imageList = allMedia
                                            .where((m) =>
                                                m.item.fileType == 'image' &&
                                                !m.item.isMissing)
                                            .map((m) => m.item.filePath)
                                            .toList();
                                        final currentIdx = imageList
                                            .indexOf(meta.item.filePath);
                                        FullScreenImageViewer.show(
                                          context,
                                          meta.item.filePath,
                                          filename:
                                              p.basename(meta.item.filePath),
                                          allImages: imageList,
                                          currentIndex:
                                              currentIdx >= 0 ? currentIdx : 0,
                                        );
                                      },
                                      child: Image.file(
                                        File(meta.item.filePath),
                                        fit: BoxFit.contain,
                                      ),
                                    )
                                  : VideoPlayerView(item: meta.item)),
                          // 全屏按钮：固定在图片容器底部居中（不再和翻页按钮重叠）
                          if (meta.item.fileType == 'image' &&
                              !meta.item.isMissing)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 12,
                              child: Center(
                                child: _FullscreenButton(
                                  onTap: () {
                                    final imageList = allMedia
                                        .where((m) =>
                                            m.item.fileType == 'image' &&
                                            !m.item.isMissing)
                                        .map((m) => m.item.filePath)
                                        .toList();
                                    final currentIdx =
                                        imageList.indexOf(meta.item.filePath);
                                    FullScreenImageViewer.show(
                                      context,
                                      meta.item.filePath,
                                      filename: p.basename(meta.item.filePath),
                                      allImages: imageList,
                                      currentIndex:
                                          currentIdx >= 0 ? currentIdx : 0,
                                    );
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // ─── 右侧翻页按钮（在 Row 最右，不在图片 Stack 内） ───
                  if (currentIndex < allMedia.length - 1)
                    _SideNavButton(
                      icon: Icons.chevron_right,
                      tooltip: '下一张',
                      onTap: () {
                        Navigator.pop(context);
                        showDialog(
                          context: context,
                          builder: (_) => _MediaDetailDialogInline(
                            meta: allMedia[currentIndex + 1],
                          ),
                        );
                      },
                    ),
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _Section('文件'),
                          _row('文件名', p.basename(meta.item.filePath)),
                          _row('路径', meta.item.filePath,
                              trailing: IconButton(
                                icon: const Icon(Icons.open_in_new, size: 14),
                                tooltip: '打开所在文件夹',
                                onPressed: () => _openFolder(context),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              )),
                          _row('大小', _formatSize(meta.item.fileSizeBytes)),
                          _row('类型', meta.item.fileType),
                          _row('MD5', meta.item.md5 ?? '-'),
                          _row('归档于', meta.item.indexedAt.toString()),
                          const SizedBox(height: 12),
                          if (meta.videoMeta != null) ...[
                            const _Section('视频'),
                            _row('分辨率', '${meta.videoMeta!.width}×${meta.videoMeta!.height}'),
                            _row('时长', _formatDuration(meta.videoMeta!.durationSec)),
                            _row('编码', meta.videoMeta!.codec),
                            _row('码率', _formatBitrate(meta.videoMeta!.bitrate)),
                            const SizedBox(height: 12),
                          ],
                          if (exif != null) ...[
                            const _Section('EXIF'),
                            _row('拍摄时间', exif.dateTaken?.toString() ?? '-'),
                            _row(
                                '相机',
                                '${exif.make ?? ''} ${exif.model ?? ''}'
                                    .trim()),
                            _row('光圈', exif.fNumber ?? '-'),
                            _row('快门', exif.exposureTime ?? '-'),
                            _row('ISO', exif.isoSpeed ?? '-'),
                            _row('焦距', exif.focalLength ?? '-'),
                            _row('分辨率',
                                '${exif.imageWidth ?? '-'}×${exif.imageHeight ?? '-'}'),
                            if (exif.latitude != null)
                              _row('坐标',
                                  '${exif.latitude!.toStringAsFixed(4)}, ${exif.longitude!.toStringAsFixed(4)}'),
                            if (exif.cityName != null)
                              _row('城市', exif.cityName!),
                            const SizedBox(height: 12),
                          ],
                          const _Section('标签'),
                          if (meta.tags.isEmpty)
                            const Text('暂无标签',
                                style:
                                    TextStyle(fontSize: 12, color: Colors.grey))
                          else
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: meta.tags
                                  .map((t) => _InlineTagChip(tag: t))
                                  .toList(),
                            ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.label, size: 16),
                            label: const Text('编辑标签'),
                            onPressed: () async {
                              await showTagEditorDialog(context,
                                  items: [meta.item]);
                              if (context.mounted) Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _row(String label, String? value, {Widget? trailing}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 64,
                child: Text(label,
                    style: const TextStyle(fontSize: 12, color: Colors.grey))),
            Expanded(
                child: Tooltip(
              message: value ?? '-',
              waitDuration: const Duration(milliseconds: 500),
              child: Text(value ?? '-',
                  style: const TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis),
            )),
            if (trailing != null) trailing,
          ],
        ),
      );

  static String _formatSize(int? bytes) {
    if (bytes == null) return '-';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}

class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
      );
}

String _formatDuration(double seconds) {
  if (seconds <= 0) return '-';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = (seconds % 60).round();
  if (h > 0) return '${h}h ${m}m ${s}s';
  if (m > 0) return '${m}m ${s}s';
  return '${s}s';
}

String _formatBitrate(int bps) {
  if (bps <= 0) return '-';
  if (bps >= 1000000) return '${(bps / 1000000).toStringAsFixed(1)} Mbps';
  return '${(bps / 1000).toStringAsFixed(0)} Kbps';
}

/// 详情页左右翻页按钮：放在整个 Row 的最左/最右，**不**叠在图片容器上
/// 解决"原图很矮时翻页按钮和全屏按钮重叠"的问题。
class _SideNavButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _SideNavButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: Colors.black.withValues(alpha: 0.45),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Tooltip(
              message: tooltip,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(icon, color: Colors.white, size: 32),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 详情页"全屏查看"按钮：固定在图片容器底部居中。
class _FullscreenButton extends StatelessWidget {
  final VoidCallback onTap;
  const _FullscreenButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Tooltip(
          message: '全屏查看',
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.fullscreen, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text('全屏',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineTagChip extends StatelessWidget {
  final Tag tag;
  const _InlineTagChip({required this.tag});
  @override
  Widget build(BuildContext context) {
    final color = _hex(tag.color) ?? Colors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(tag.name,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }
}

// ────────────────────────────────────────────
// 胶囊弹窗（统一定制进度弹窗）
// 用于全库对账、缩略图扫描、区域分析等。
// 显示标题 + 进度条 + 当前项 + 计数，自动适配明暗模式。
// ────────────────────────────────────────────

Future<void> _showTaskProgressDialog(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required Future<int> Function(
    void Function(String status, int current, int total) onProgress,
  ) run,
  required String completedMessage,
}) async {
  final statusNotifier = ValueNotifier<_TaskStatus>(const _TaskStatus(
    current: 0,
    total: 1,
    label: '准备中…',
  ));
  final resultNotifier = ValueNotifier<String?>(null);
  bool cancelled = false;

  // showDialog 返回的 Future 在弹窗被 pop 时完成，用于 finally 中释放资源
  final dialogFuture = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => CallbackShortcuts(
      bindings: {
        SingleActivator(LogicalKeyboardKey.escape): () {
          if (cancelled) return;
          // 已完成/失败时 ESC 直接关闭，运行时 ESC 触发取消
          Navigator.pop(ctx);
          if (resultNotifier.value == null) {
            cancelled = true;
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: _TaskProgressDialog(
          title: title,
          status: statusNotifier,
          resultMessage: resultNotifier,
          onCancel: () {
            cancelled = true;
            Navigator.pop(ctx);
          },
          onDone: () => Navigator.pop(ctx),
        ),
      ),
    ),
  );

  try {
    final result = await run((status, current, total) {
      if (cancelled) throw _TaskCancelled();
      statusNotifier.value = _TaskStatus(
        current: current,
        total: total,
        label: status,
      );
    });

    if (!cancelled) {
      // 进度显示为 100%，结果文字切换到完成信息
      final total = statusNotifier.value.total;
      statusNotifier.value = _TaskStatus(
        current: total,
        total: total,
        label: '完成',
      );
      resultNotifier.value = completedMessage.replaceFirst('{}', '$result');
      if (context.mounted) {
        ref.read(browserRefreshSignalProvider.notifier).state++;
      }
      // 1.5 秒后自动关闭；用户也可以手动点"完成"提前关闭
      Future<void>.delayed(const Duration(milliseconds: 1500)).then((_) {
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    }
  } on _TaskCancelled {
    // onCancel 已经 pop 了 dialog，无需额外处理
  } catch (e) {
    // 失败信息也在弹窗内显示，不再弹出底部 SnackBar
    resultNotifier.value = '$title 失败：$e';
  } finally {
    await dialogFuture;
    statusNotifier.dispose();
    resultNotifier.dispose();
  }
}

class _TaskCancelled implements Exception {}

class _TaskStatus {
  final int current;
  final int total;
  final String label;
  const _TaskStatus({
    required this.current,
    required this.total,
    required this.label,
  });
}

class _TaskProgressDialog extends StatelessWidget {
  final String title;
  final ValueNotifier<_TaskStatus> status;
  final ValueNotifier<String?> resultMessage;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  const _TaskProgressDialog({
    required this.title,
    required this.status,
    required this.resultMessage,
    required this.onCancel,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark
          ? const Color(0xFF252836)
          : const Color(0xFFF8F9FC),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: scheme.onSurface)),
            const SizedBox(height: 16),
            ValueListenableBuilder<String?>(
              valueListenable: resultMessage,
              builder: (_, result, __) {
                return ValueListenableBuilder<_TaskStatus>(
                  valueListenable: status,
                  builder: (_, s, __) {
                    final done = result != null;
                    final success = done && s.label == '完成';
                    final ratio = success
                        ? 1.0
                        : (s.total > 0 ? s.current / s.total : 0.0);
                    final pct = (ratio * 100).toStringAsFixed(0);
                    return Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: ratio.clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: scheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation(scheme.primary),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                done ? result : s.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: done
                                      ? (success
                                          ? scheme.onSurface
                                          : Colors.red.shade700)
                                      : scheme.onSurfaceVariant,
                                  fontWeight: done
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (s.total > 0 || done)
                              Text(
                                done
                                    ? (success ? '完成' : '失败')
                                    : '$pct%',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: done
                                      ? (success
                                          ? Colors.green
                                          : Colors.red)
                                      : scheme.primary,
                                ),
                              ),
                          ],
                        ),
                        if (s.total > 0 && !done) ...[
                          const SizedBox(height: 4),
                          Text('${s.current} / ${s.total}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant.withOpacity(0.7))),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ValueListenableBuilder<String?>(
                valueListenable: resultMessage,
                builder: (_, result, __) {
                  return TextButton(
                    onPressed: result != null ? onDone : onCancel,
                    child: Text(
                      result != null ? '完成' : '取消',
                      style: TextStyle(color: scheme.onSurfaceVariant.withOpacity(0.7)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 把 Md5Helper 引用为别名，避免 browser 顶部循环 import
