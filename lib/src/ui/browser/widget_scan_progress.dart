// ============================================================
// lib/src/ui/browser/widget_scan_progress.dart
// 扫描进度面板：非阻塞式，嵌入浏览器页面顶部
// 支持展开/收起，显示详细统计、速度、ETA
// ============================================================
import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/service_media_scanner.dart';
import '../../services/service_scan_controller.dart';

/// 非阻塞扫描进度面板
/// 嵌入在浏览器页面顶部，不遮挡内容区域
class ScanProgressPanel extends StatefulWidget {
  final ScanProgress progress;
  final ScanController controller;
  final bool expanded;

  const ScanProgressPanel({
    super.key,
    required this.progress,
    required this.controller,
    this.expanded = false,
  });

  @override
  State<ScanProgressPanel> createState() => _ScanProgressPanelState();
}

class _ScanProgressPanelState extends State<ScanProgressPanel> {
  late bool _expanded;
  StreamSubscription<ScanState>? _stateSubscription;
  ScanState _currentState = ScanState.scanning;
  bool _showConfirmDialog = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.expanded;
    _currentState = widget.controller.state;
    _stateSubscription = widget.controller.stateStream.listen((state) {
      if (mounted && _currentState != state) {
        setState(() => _currentState = state);
      }
    });
  }

  @override
  void didUpdateWidget(covariant ScanProgressPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.progress.phase == ScanPhase.reconciling) {
      setState(() => _expanded = true);
    }
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final phaseLabel = _phaseLabel(widget.progress.phase);
    final ratio = widget.progress.ratio;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_expanded) _buildCollapsed(isDark, phaseLabel, ratio),
        if (_expanded) _buildExpanded(isDark, phaseLabel, ratio),
        if (_showConfirmDialog) _buildConfirmDialog(isDark),
      ],
    );
  }

  Widget _buildCollapsed(bool isDark, String phaseLabel, double ratio) {
    final p = widget.progress;
    return InkWell(
      onTap: () => setState(() => _expanded = true),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        color: isDark
            ? const Color(0xFF1A1B2E)
            : const Color(0xFFF0F4FF),
        child: Row(
          children: [
            _buildStateIcon(),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$phaseLabel  ${p.current}/${p.total}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  LinearProgressIndicator(
                    value: ratio,
                    minHeight: 3,
                    backgroundColor: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.08),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                p.currentFile,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.expand_more,
              size: 16,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpanded(bool isDark, String phaseLabel, double ratio) {
    final p = widget.progress;
    final phaseColor = p.phase == ScanPhase.reconciling
        ? (isDark ? Colors.orange[300]! : Colors.orange[700]!)
        : Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: isDark ? const Color(0xFF1E1F2D) : Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                p.phase == ScanPhase.reconciling
                    ? Icons.sync
                    : Icons.photo_library_outlined,
                size: 18,
                color: phaseColor,
              ),
              const SizedBox(width: 8),
              Text(
                p.phase == ScanPhase.reconciling ? '正在对账...' : '正在扫描媒体文件',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: phaseColor,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.expand_less, size: 18),
                tooltip: '收起',
                onPressed: () => setState(() => _expanded = false),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.08),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _statChip('进度', '${p.current} / ${p.total}', Icons.list_alt,
                  isDark),
              _statChip('新增', '${p.added}', Icons.add_circle_outline,
                  isDark, Colors.green),
              _statChip('重复', '${p.duplicates}', Icons.content_copy,
                  isDark, Colors.orange),
              if (p.speed > 0)
                _statChip('速度', p.speedLabel, Icons.speed, isDark),
              if (p.eta != null)
                _statChip('剩余', p.etaLabel, Icons.schedule, isDark),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.folder_open_outlined,
                  size: 14,
                  color: isDark ? Colors.white54 : Colors.black54),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  p.currentFile,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildControlButtons(isDark),
        ],
      ),
    );
  }

  Widget _statChip(
    String label,
    String value,
    IconData icon,
    bool isDark, [
    MaterialColor? colorOverride,
  ]) {
    final color = colorOverride ?? (isDark ? Colors.white70 : Colors.black87);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color.withOpacity(0.6)),
        const SizedBox(width: 3),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: color.withOpacity(0.6),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStateIcon() {
    if (_currentState == ScanState.paused) {
      return const Icon(Icons.pause_circle_filled,
          size: 16, color: Colors.orange);
    }
    if (_currentState == ScanState.stopping) {
      return const Icon(Icons.stop_circle, size: 16, color: Colors.red);
    }
    return SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor:
            AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
      ),
    );
  }

  Widget _buildControlButtons(bool isDark) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_currentState == ScanState.scanning)
          TextButton.icon(
            onPressed: widget.controller.pause,
            icon: const Icon(Icons.pause, size: 16),
            label: const Text('暂停'),
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.white70 : Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
          ),
        if (_currentState == ScanState.paused)
          TextButton.icon(
            onPressed: widget.controller.resume,
            icon: const Icon(Icons.play_arrow, size: 16),
            label: const Text('继续'),
            style: TextButton.styleFrom(
              foregroundColor: scheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
          ),
        const SizedBox(width: 12),
        if (_currentState == ScanState.scanning ||
            _currentState == ScanState.paused)
          TextButton.icon(
            onPressed: () {
              widget.controller.requestStop();
              setState(() => _showConfirmDialog = true);
            },
            icon: const Icon(Icons.stop_circle, size: 16),
            label: const Text('停止'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
          ),
      ],
    );
  }

  Widget _buildConfirmDialog(bool isDark) {
    final hasScanned = widget.controller.scannedCount > 0;
    return Container(
      width: double.infinity,
      color: isDark
          ? Colors.black.withOpacity(0.6)
          : Colors.black.withOpacity(0.3),
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber, size: 32, color: Colors.orange),
              const SizedBox(height: 8),
              const Text(
                '确认停止扫描？',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                hasScanned
                    ? '当前已扫描 ${widget.controller.scannedCount} 个文件。'
                    : '扫描尚未开始。',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() => _showConfirmDialog = false);
                      widget.controller.cancelStop();
                    },
                    child: const Text('继续扫描'),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: () {
                      setState(() => _showConfirmDialog = false);
                      widget.controller.confirmStop();
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('确认停止'),
                  ),
                ],
              ),
              if (hasScanned)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child:                   Text(
                    '已扫描的内容会自动保存到数据库',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.grey[500],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _phaseLabel(ScanPhase phase) {
    switch (phase) {
      case ScanPhase.indexing:
        return '扫描中';
      case ScanPhase.reconciling:
        return '对账中';
      case ScanPhase.rebuildingIndex:
        return '更新时间轴索引中';
      case ScanPhase.generatingThumbnails:
        return '生成缩略图中';
    }
  }
}
