// ============================================================
// lib/src/ui/browser/widget_pixel_thumb.dart
// 统一缩略图组件
// ------------------------------------------------------------
// 设计目标：
// 1. 单一组件覆盖大图 / 中图 / 列表三处使用点，避免 Image.file 散落各处。
// 2. 双清晰度策略：
//    - 初始 / 快速滚动时使用 cacheWidth 限缩解码（300px，节省内存/CPU）
//    - 停留 >= [upgradeDelay] 后，自动切到原图解码（cacheWidth = null）
//    - 离开视口时降级回缩略图，节省内存
// 3. 冷区（hot=false）→ 显示数据库元数据占位 widget，
//    **完全**不触发 Image.file IO/解码。
// 4. 优先使用数据库存的 thumbnailPath（持久化缓存），
//    缺失时回退到原文件（图片用 Image.file，视频用 Icon）。
// 5. 复用时通过 [PixelThumbHotProvider] 拿到外部 hot 决策，
//    避免每个 item 各自监听 ScrollController。
// ============================================================
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../db/database.dart';

/// 升级原图的等待时长：停留这么久都没滚动 / 离开视口 → 升级为原图解码
const Duration kThumbUpgradeDelay = Duration(seconds: 5);

/// 缩略图解码宽度上限（解码时缩小到 300 像素，节省内存/解码时间）
const int kThumbCacheWidth = 300;

/// 升级原图后的解码宽度上限：1080p 清晰度（屏幕够用），不会把 4000px 的原图全量解码
const int kFullCacheWidth = 1920;

/// "外部 hot 决策" provider。
///   - true  = 当前 item 在视口附近，应渲染缩略图
///   - false = 冷区，应显示占位 widget（不触发 IO）
///
/// 决策逻辑通常在 grid 级别统一监听 ScrollController 后给出，
/// 见 [PixelThumbHotController]（widget_media_grid_item.dart）。
typedef PixelThumbHotProvider = bool Function();

/// 缩略图渲染模式。
enum PixelThumbQuality {
  /// 缩略图：cacheWidth = 300，省内存
  thumb,
  /// 原图：cacheWidth = null，清晰
  full,
}

/// 缩略图组件（统一封装）
///
/// 用法：
/// ```
/// PixelThumb(
///   item: meta.item,
///   hot: () => myHotFlag,
///   upgradeAfter: kThumbUpgradeDelay,
/// )
/// ```
class PixelThumb extends StatefulWidget {
  final MediaItem item;

  /// 外部 hot 决策回调（true → 显示图片；false → 显示占位）
  final PixelThumbHotProvider hot;

  /// 外部滚动状态（true = 正在滚动；false = 已静止）。
  /// 仅当 scrolling == false 且 hot == true 时，升级计时才会计时。
  /// 默认 false（静态场景永远不抑制升级）。
  final bool scrolling;

  /// 停留超过这个时长（且 scrolling == false）后，升级为原图解码。
  final Duration upgradeAfter;

  /// 缩略图缺失 / 加载失败时的占位 widget（可选）
  final WidgetBuilder? errorBuilder;

  const PixelThumb({
    super.key,
    required this.item,
    required this.hot,
    this.scrolling = false,
    this.upgradeAfter = kThumbUpgradeDelay,
    this.errorBuilder,
  });

  @override
  State<PixelThumb> createState() => _PixelThumbState();
}

class _PixelThumbState extends State<PixelThumb> {
  /// 当前渲染模式
  PixelThumbQuality _quality = PixelThumbQuality.thumb;

  /// 升级原图的 Timer
  Timer? _upgradeTimer;

  /// 上一次的 scrolling 状态（用于避免不必要的 timer 操作）
  bool _lastScrolling = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant PixelThumb old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final hot = widget.hot();
    final scrolling = widget.scrolling;

    if (hot && !scrolling) {
      // 热区中 + 滚动已停止 → 启动升级计时
      _upgradeTimer ??= Timer(widget.upgradeAfter, _upgrade);
    } else {
      // 冷区 或 正在滚动 → 取消升级计时 + 降级
      _upgradeTimer?.cancel();
      _upgradeTimer = null;
      if (_quality == PixelThumbQuality.full) {
        setState(() => _quality = PixelThumbQuality.thumb);
      }
    }
    _lastScrolling = scrolling;
  }

  void _upgrade() {
    if (!mounted) return;
    if (!widget.hot()) return; // 离开视口前已冷的话不要升
    setState(() => _quality = PixelThumbQuality.full);
  }

  @override
  void dispose() {
    _upgradeTimer?.cancel();
    _upgradeTimer = null;
    super.dispose();
  }

  /// 渲染"原图"模式时清掉对应缓存键，节省内存。
  /// ImageCache 是 LRU + 上限控制，重复 key 会复用。
  void _evictIfFull() {
    if (_quality != PixelThumbQuality.full) return;
    final path = _imagePath();
    if (path == null) return;
    // 异步 evict，不阻塞 build
    FileImage(File(path)).evict();
  }

  String? _imagePath() {
    // full 模式：使用原图（更清晰）。但即使 full 也用 cacheWidth=1920 限制解码宽度，
    // 避免 4000px 原图全量解码爆内存。
    if (_quality == PixelThumbQuality.full) {
      return widget.item.fileType == 'image' ? widget.item.filePath : null;
    }
    // thumb 模式：优先用数据库存的缩略图（200x200 JPG，已生成），降级到原图
    final tp = widget.item.thumbnailPath;
    if (tp != null && File(tp).existsSync()) return tp;
    return widget.item.fileType == 'image' ? widget.item.filePath : null;
  }

  @override
  Widget build(BuildContext context) {
    // 1) 缺省文件
    if (widget.item.isMissing) {
      return _MissingPlaceholder();
    }

    // 2) 冷区：占位 widget，不触发 IO
    if (!widget.hot()) {
      return _ThumbPlaceholder(item: widget.item);
    }

    // 3) 视频
    if (widget.item.fileType == 'video') {
      return _buildVideo();
    }

    // 4) 图片
    return _buildImage();
  }

  Widget _buildImage() {
    final path = _imagePath();
    if (path == null) {
      return _MissingPlaceholder();
    }
    final file = File(path);
    // full: 1920（原图，但限制解码宽度避免 4000px OOM）
    // thumb: 300（缩略图解码）
    final cacheWidth = _quality == PixelThumbQuality.full
        ? kFullCacheWidth
        : kThumbCacheWidth;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          file,
          fit: BoxFit.cover,
          cacheWidth: cacheWidth,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, wasSync) {
            if (wasSync) return child;
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: child,
            );
          },
          errorBuilder: (_, __, ___) =>
              widget.errorBuilder?.call(context) ?? const _MissingPlaceholder(),
        ),
        // 升级原图完成时打个小角标提示（仅 _quality==full 显示）
        if (_quality == PixelThumbQuality.full)
          const Positioned(
            right: 4,
            bottom: 4,
            child: _HiResBadge(),
          ),
      ],
    );
  }

  Widget _buildVideo() {
    final tp = widget.item.thumbnailPath;
    if (tp != null && File(tp).existsSync()) {
      return Image.file(
        File(tp),
        fit: BoxFit.cover,
        // 视频缩略图原本就是原图大小的截帧，full 模式没必要切原文件
        cacheWidth:
            _quality == PixelThumbQuality.full ? kFullCacheWidth : kThumbCacheWidth,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _videoFallback(),
      );
    }
    return _videoFallback();
  }

  Widget _videoFallback() => Container(
        color: Colors.black87,
        child: const Center(
          child:
              Icon(Icons.videocam_outlined, color: Colors.white70, size: 40),
        ),
      );
}

// === 占位 / 角标 widget ===

/// 缺省文件占位
class _MissingPlaceholder extends StatelessWidget {
  const _MissingPlaceholder();
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? const Color(0xFF1E1F2D) : Colors.grey.shade200,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: isDark
              ? Colors.white.withOpacity(0.7)
              : Colors.grey.shade500,
          size: 40,
        ),
      ),
    );
  }
}

/// 冷区占位：显示文件名 / 文件类型，不触发 IO
class _ThumbPlaceholder extends StatelessWidget {
  final MediaItem item;
  const _ThumbPlaceholder({required this.item});
  @override
  Widget build(BuildContext context) {
    final isVideo = item.fileType == 'video';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerLow,
      child: Stack(
        children: [
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
          Positioned(
            left: 6,
            right: 6,
            bottom: 4,
            child: Text(
              p.basename(item.filePath),
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
    );
  }
}

/// 升级原图后的"高清"小角标
class _HiResBadge extends StatelessWidget {
  const _HiResBadge();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.high_quality_outlined, size: 10, color: Colors.white),
            SizedBox(width: 2),
            Text('原图', style: TextStyle(color: Colors.white, fontSize: 9)),
          ],
        ),
      );
}
