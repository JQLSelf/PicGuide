// ============================================================
// lib/src/ui/widgets/view_full_screen_image.dart
// 全屏图片查看器：支持缩放、平移、左右切换
// ============================================================
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:path/path.dart' as p;

class FullScreenImageViewer extends StatefulWidget {
  final String imagePath;
  final String? filename;
  final List<String>? allImages;
  final int currentIndex;

  const FullScreenImageViewer({
    super.key,
    required this.imagePath,
    this.filename,
    this.allImages,
    this.currentIndex = 0,
  });

  static Future<void> show(
    BuildContext context,
    String imagePath, {
    String? filename,
    List<String>? allImages,
    int currentIndex = 0,
  }) async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, __, ___) => FullScreenImageViewer(
          imagePath: imagePath,
          filename: filename,
          allImages: allImages,
          currentIndex: currentIndex,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _showControls = true;
  late String _currentPath;
  late int _currentIndex;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _currentPath = widget.imagePath;
    _currentIndex = widget.currentIndex;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _close();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _previousImage();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _nextImage();
      }
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _close() {
    Navigator.pop(context);
  }

  void _previousImage() {
    if (widget.allImages == null || _currentIndex <= 0) return;
    setState(() {
      _currentIndex--;
      _currentPath = widget.allImages![_currentIndex];
    });
  }

  void _nextImage() {
    if (widget.allImages == null ||
        _currentIndex >= widget.allImages!.length - 1) return;
    setState(() {
      _currentIndex++;
      _currentPath = widget.allImages![_currentIndex];
    });
  }

  bool get _hasPrevious => widget.allImages != null && _currentIndex > 0;
  bool get _hasNext =>
      widget.allImages != null && _currentIndex < widget.allImages!.length - 1;

  Future<void> _openFolder() async {
    final folderPath = p.dirname(_currentPath);
    try {
      if (Platform.isWindows) {
        await Process.run('explorer', ['/select,', _currentPath]);
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
        await Process.run('open', ['-R', _currentPath]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法打开文件夹: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filename = widget.filename ?? p.basename(_currentPath);
    final hasNavigation =
        widget.allImages != null && widget.allImages!.length > 1;

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF121212)
          : const Color(0xFFF5F5F5),
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (_, event) {
          _handleKeyEvent(event);
          return KeyEventResult.handled;
        },
        // 整体结构：Column = 顶部 AppBar 风格工具条 + 中间图片 Row + 底部提示
        // 翻页按钮移到图片 Row 的左右两侧（**不**在图片 Stack 内），
        // 避免和底部提示条在矮图上重叠。
        child: Column(
          children: [
            // 顶部工具条
            FadeTransition(
              opacity: _animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -1),
                  end: Offset.zero,
                ).animate(_controller),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            tooltip: '关闭',
                            onPressed: _close,
                            iconSize: 24,
                          ),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  filename,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                                if (hasNavigation)
                                  Text(
                                    '${_currentIndex + 1} / ${widget.allImages!.length}',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.folder_open,
                                color: Colors.white),
                            tooltip: '打开所在文件夹',
                            onPressed: _openFolder,
                            iconSize: 24,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // 中间：图片 + 左右翻页按钮（翻页按钮在 Row 边缘，**不**叠在图片上）
            Expanded(
              child: Row(
                children: [
                  if (hasNavigation)
                    _SideNavButton(
                      icon: Icons.chevron_left,
                      tooltip: '上一张',
                      enabled: _hasPrevious,
                      onTap: _previousImage,
                    ),
                  Expanded(
                    child: PhotoView(
                      imageProvider: FileImage(File(_currentPath)),
                      minScale: PhotoViewComputedScale.contained * 0.5,
                      maxScale: PhotoViewComputedScale.covered * 6.0,
                      initialScale: PhotoViewComputedScale.contained,
                      basePosition: Alignment.center,
                      backgroundDecoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF121212)
                            : const Color(0xFFF5F5F5),
                      ),
                      loadingBuilder: (context, event) => const Center(
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white54),
                          ),
                        ),
                      ),
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.broken_image,
                                color: Colors.white54, size: 80),
                            const SizedBox(height: 16),
                            Text('无法加载图片',
                                style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.7))),
                          ],
                        ),
                      ),
                      onTapUp: (context, details, controllerValue) =>
                          _toggleControls(),
                    ),
                  ),
                  if (hasNavigation)
                    _SideNavButton(
                      icon: Icons.chevron_right,
                      tooltip: '下一张',
                      enabled: _hasNext,
                      onTap: _nextImage,
                    ),
                ],
              ),
            ),
            // 底部提示条（**不**在图片 Stack 内，永远在底部）
            if (_showControls)
              FadeTransition(
                opacity: _animation,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: SafeArea(
                    top: false,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.mouse,
                                color: Colors.white70, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              hasNavigation
                                  ? '← → 切换 · 拖拽平移 · 双击放大/还原 · ESC退出'
                                  : '拖拽平移 · 双击放大/还原 · ESC退出',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 全屏查看器左右翻页按钮：放在 Row 的边缘，**不**叠在 PhotoView 上。
class _SideNavButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;
  const _SideNavButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: enabled ? 1.0 : 0.3,
          child: Material(
            color: Colors.black.withValues(alpha: 0.45),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: enabled ? onTap : null,
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
      ),
    );
  }
}
