// ============================================================
// lib/src/ui/browser/widget_media_grid_item.dart
// 单个媒体格子：缩略图 + 标签 chip + EXIF 简要
// + 选中态 / 多选态
// + 懒加载：只有「视口上下各 ~20 项」热区才渲染缩略图，其他用占位
// ============================================================
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../db/database.dart';
import 'view_video_player.dart';
import '../tags/dialog_tag_editor.dart';
import 'widget_pixel_thumb.dart' show PixelThumb;

class MediaGridItem extends ConsumerStatefulWidget {
  final MediaItemWithMeta meta;
  final bool isCutSource;
  final bool selected;
  final bool multiSelect;

  const MediaGridItem({
    super.key,
    required this.meta,
    this.isCutSource = false,
    this.selected = false,
    this.multiSelect = false,
  });

  @override
  ConsumerState<MediaGridItem> createState() => _MediaGridItemState();
}

class _MediaGridItemState extends ConsumerState<MediaGridItem> {
  /// true = 缩略图热区（视口 ± 20 项），允许 Image.file 加载；
  /// false = 冷区，用占位 widget（只读数据库元数据，不触发 IO/解码）。
  bool _hot = false;

  /// true = 正在滚动（滚动停止 150ms 内仍算滚动），抑制原图升级
  bool _scrolling = false;

  /// 滚动停止判定：每次 scroll 事件重置此 timer，
  /// timer 到期表示滚动已停止。
  Timer? _scrollStopTimer;

  /// 滚动停止判定阈值（150ms 无 scroll 事件即认为停止）
  static const _kScrollStopDelay = Duration(milliseconds: 150);

  ScrollPosition? _watchedPos;
  void _onScroll() {
    if (!mounted) return;
    // 标记为"正在滚动"，取消旧 timer，启动新 timer
    if (!_scrolling) {
      setState(() => _scrolling = true);
    }
    _scrollStopTimer?.cancel();
    _scrollStopTimer = Timer(_kScrollStopDelay, () {
      if (!mounted) return;
      setState(() => _scrolling = false);
    });
    _recomputeHot();
  }

  @override
  void initState() {
    super.initState();
    // 第一帧后再绑定 ScrollPosition + 计算初始热区
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _attachScrollWatcher();
      _recomputeHot();
    });
  }

  @override
  void didUpdateWidget(MediaGridItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // meta / selected 变化后重算一次（位置/几何可能没变，但 selected 不会影响 hot）
    _recomputeHot();
  }

  /// 找到当前 item 最近的 ScrollableState，把它的 position 接到 listener
  /// 注意：grid 是 lazy build 的，滚出视口的 item 会被 dispose，
  ///       State.dispose() 会 removeListener，不会泄漏。
  void _attachScrollWatcher() {
    final s = Scrollable.maybeOf(context);
    final pos = s?.position;
    if (pos == _watchedPos) return;
    if (_watchedPos != null) _watchedPos!.removeListener(_onScroll);
    _watchedPos = pos;
    _watchedPos?.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollStopTimer?.cancel();
    _watchedPos?.removeListener(_onScroll);
    _watchedPos = null;
    super.dispose();
  }

  /// 视口判断：
  /// - 取自己 renderBox 相对 scrollable viewport 的 y 区间
  /// - 热区 = viewport 上下各 ± hotPadding（默认 20 × 平均行高）
  void _recomputeHot() {
    if (!mounted) return;
    // 视口换了（比如 grid 替换）→ 重新订阅
    _attachScrollWatcher();
    final s = Scrollable.maybeOf(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (s == null || renderBox == null || !renderBox.attached) {
      // 拿不到视口信息时（极少见），保守按 hot 处理
      if (!_hot) setState(() => _hot = true);
      return;
    }
    final scrollableBox = s.context.findRenderObject() as RenderBox?;
    if (scrollableBox == null) {
      if (!_hot) setState(() => _hot = true);
      return;
    }
    final myTop =
        renderBox.localToGlobal(Offset.zero, ancestor: scrollableBox).dy;
    final myBottom = myTop + renderBox.size.height;
    final viewportH = scrollableBox.size.height;
    final scrollOffset = s.position.pixels;
    final viewportTop = scrollOffset;
    final viewportBottom = scrollOffset + viewportH;

    // 估算行高：grid 列数从 mediaQuery 无法直接拿 → 粗略 240 px
    // 偏大 30% 不会出问题，反而能避免快速滚动时黑屏闪烁
    const rowH = 240.0;
    final pad = 20.0 * rowH; // 视口上下各 20 项

    final nextHot =
        (myBottom >= viewportTop - pad) && (myTop <= viewportBottom + pad);
    if (nextHot != _hot) {
      setState(() => _hot = nextHot);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = widget.meta;
    final missing = meta.item.isMissing;
    // 用 LayoutBuilder 计算 cell 的宽/高（缩略图 1:1 + 固定 footer）
    // ——MasonryGridView 不会给 cell 一个有限高度，直接用 Column+Expanded 会布局失败
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        // 标签行 ~22、日期行 ~18、文件名行 ~18；footer 留 6 的内边距
        final tagRow = meta.tags.isNotEmpty ? 22.0 : 0.0;
        final dateRow = meta.exif?.dateTaken != null ? 18.0 : 0.0;
        final nameRow = 18.0; // 文件名始终显示
        final footerH = tagRow + dateRow + nameRow + 6;
        final thumbH = w; // 1:1
        final totalH = thumbH + footerH;
        return Opacity(
          opacity: (widget.isCutSource || missing) ? 0.45 : 1.0,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E1F2D).withOpacity(0.85)
                  : Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.selected
                    ? Theme.of(context).colorScheme.primary
                    : (Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.04)),
                width: widget.selected ? 2.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.black.withOpacity(0.2)
                      : Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: w,
                height: totalH,
                child: Stack(
                  children: [
                    // 缩略图（固定 1:1）；冷区用占位 widget
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: thumbH,
                      child: missing
                          ? const _MissingPlaceholder()
                          : PixelThumb(
                              item: meta.item,
                              hot: () => _hot,
                              scrolling: _scrolling,
                            ),
                    ),
                    // 底部信息行：标签 + 日期 + 文件名
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: footerH,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(6, 4, 6, 2),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (meta.tags.isNotEmpty)
                              SizedBox(
                                height: 16,
                                child: Wrap(
                                  spacing: 4,
                                  runSpacing: 0,
                                  children: meta.tags
                                      .take(3)
                                      .map((t) => _TagChip(tag: t))
                                      .toList(),
                                ),
                              ),
                            if (meta.exif?.dateTaken != null)
                              Text(
                                _formatDate(meta.exif!.dateTaken!),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      // 底部日期颜色改为 onSurface 深色，避免在图片缩略图覆盖区看不清楚
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            // 文件名始终显示
                            Text(
                              meta.item.fileName,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 缺省文件角标
                    if (missing)
                      const Positioned(
                        top: 4,
                        left: 4,
                        child: _MissingBadgeSmall(),
                      ),
                    // 选中标记
                    if (widget.selected || widget.multiSelect)
                      const Positioned(
                        top: 4,
                        right: 4,
                        child: _SelectBadgeSmall(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  void _showDetail(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _MediaDetailDialog(meta: widget.meta),
    );
  }
}

/// 冷区占位：显示数据库元数据（标签 / 日期 / 文件名），不触发磁盘 IO / 解码。
/// 关键：完全**不**调用 Image.file，避免触发磁盘 IO / 解码。
class _HotPlaceholder extends StatelessWidget {
  final MediaItemWithMeta meta;
  const _HotPlaceholder({required this.meta});

  @override
  Widget build(BuildContext context) {
    final isVideo = meta.item.fileType == 'video';
    final tags = meta.tags;
    final date = meta.exif?.dateTaken;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Stack(
        children: [
          // 中央图标（带背景）
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isVideo ? Icons.videocam_outlined : Icons.image_outlined,
                size: 28,
                color: isDark
                    ? Colors.white.withOpacity(0.8)
                    : Colors.grey.shade600,
              ),
            ),
          ),
          // 左下角标签
          if (tags.isNotEmpty)
            Positioned(
              left: 6,
              right: 6,
              bottom: 30,
              child: Wrap(
                spacing: 3,
                runSpacing: 0,
                children: tags.take(3).map((t) {
                  final color = _hexColor(t.color) ?? Colors.blue;
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withOpacity(0.5)),
                    ),
                    child: Text(
                      t.name,
                      style: TextStyle(
                          fontSize: 9,
                          color: color,
                          fontWeight: FontWeight.w500),
                    ),
                  );
                }).toList(),
              ),
            ),
          // 右下角日期 + 文件名
          Positioned(
            left: 6,
            right: 6,
            bottom: 4,
            child: Row(
              children: [
                if (date != null)
                  Text(
                    _fmtDate(date),
                    style: TextStyle(
                      fontSize: 9,
                      color: isDark
                          ? Colors.white.withOpacity(0.9)
                          : scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (date != null) const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    meta.item.fileName,
                    style: TextStyle(
                      fontSize: 9,
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  Color? _hexColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return null;
    }
  }
}

/// 缺省文件的占位（broken 图标）
class _MissingPlaceholder extends StatelessWidget {
  const _MissingPlaceholder();
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? const Color(0xFF1E1F2D) : Colors.grey.shade200,
      child: Center(
          child: Icon(Icons.broken_image_outlined,
              color:
                  isDark ? Colors.white.withOpacity(0.7) : Colors.grey.shade500,
              size: 40)),
    );
  }
}

// ─── 缩略图 ───
// 注意：本 widget 只在 MediaGridItem._hot == true 时才会被构建。
// 冷区走 _HotPlaceholder 路径，**完全**不会触发 Image.file / VideoThumbnail。
//
// 优先使用数据库中存储的缩略图路径（持久化缓存），
// 如果没有则回退到动态生成或原文件。

// _Thumbnail / _HotPlaceholder 已被 PixelThumb（widget_pixel_thumb.dart）统一替换。
// 保留 _HotPlaceholder 注释作为热区机制文档；_Thumbnail 类整个删除。
//
// 留空：见下 _HotPlaceholder


// ─── 标签 chip ───

class _TagChip extends StatelessWidget {
  final Tag tag;
  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    final color = _hexColor(tag.color) ?? Colors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        tag.name,
        style:
            TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }

  Color? _hexColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return null;
    }
  }
}

/// 缩略图上的"缺失文件"角标
class _MissingBadgeSmall extends StatelessWidget {
  const _MissingBadgeSmall();
  @override
  Widget build(BuildContext context) => Container(
        width: 20,
        height: 20,
        decoration: const BoxDecoration(
          color: Colors.orange,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.warning_amber, size: 12, color: Colors.white),
      );
}

/// 缩略图上的"已选中"角标
class _SelectBadgeSmall extends StatelessWidget {
  const _SelectBadgeSmall();
  @override
  Widget build(BuildContext context) => Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.primary,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: const Icon(Icons.check, size: 12, color: Colors.white),
      );
}

// ─── 详情弹窗 ───

class _MediaDetailDialog extends ConsumerWidget {
  final MediaItemWithMeta meta;
  const _MediaDetailDialog({required this.meta});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exif = meta.exif;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 640),
        child: Column(
          children: [
            AppBar(
              title: Text(p.basename(meta.item.filePath)),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  tooltip: '编辑标签',
                  icon: const Icon(Icons.label_outline),
                  onPressed: () async {
                    await showTagEditorDialog(context, items: [meta.item]);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
                IconButton(
                  tooltip: '关闭',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Expanded(
              child: Row(
                children: [
                  // 预览
                  Expanded(
                    flex: 3,
                    child: Container(
                      color: Colors.black,
                      child: Center(
                        child: meta.item.fileType == 'image'
                            ? Image.file(
                                File(meta.item.filePath),
                                fit: BoxFit.contain,
                              )
                            : VideoPlayerView(item: meta.item),
                      ),
                    ),
                  ),
                  // EXIF 信息 + 标签
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _section('文件'),
                          _infoRow('文件名', p.basename(meta.item.filePath)),
                          _infoRow('大小', _formatSize(meta.item.fileSizeBytes)),
                          _infoRow('类型', meta.item.fileType),
                          const SizedBox(height: 12),
                          if (exif != null) ...[
                            _section('EXIF'),
                            _infoRow('拍摄时间', exif.dateTaken?.toString() ?? '-'),
                            _infoRow(
                                '相机',
                                '${exif.make ?? ''} ${exif.model ?? ''}'
                                    .trim()),
                            _infoRow('光圈', exif.fNumber ?? '-'),
                            _infoRow('快门', exif.exposureTime ?? '-'),
                            _infoRow('ISO', exif.isoSpeed ?? '-'),
                            _infoRow('焦距', exif.focalLength ?? '-'),
                            _infoRow('分辨率',
                                '${exif.imageWidth ?? '-'}×${exif.imageHeight ?? '-'}'),
                            if (exif.latitude != null)
                              _infoRow('坐标',
                                  '${exif.latitude!.toStringAsFixed(4)}, ${exif.longitude!.toStringAsFixed(4)}'),
                            if (exif.cityName != null)
                              _infoRow('城市', exif.cityName!),
                            const SizedBox(height: 12),
                          ],
                          _section('标签'),
                          if (meta.tags.isEmpty)
                            const Text('暂无标签',
                                style:
                                    TextStyle(fontSize: 12, color: Colors.grey))
                          else
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: meta.tags
                                  .map((t) => _TagChip(tag: t))
                                  .toList(),
                            ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children: [
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

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
      );

  Widget _infoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value ?? '-', style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  String _formatSize(int? bytes) {
    if (bytes == null) return '-';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}
