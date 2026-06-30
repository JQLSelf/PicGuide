// ============================================================
// lib/src/ui/browser/dialog_scan_config.dart
// 扫描确认弹窗：显示路径、确认开始扫描
// ============================================================
import 'package:flutter/material.dart';

/// 扫描确认弹窗返回结果
class ScanConfigResult {
  final bool confirmed;

  ScanConfigResult({required this.confirmed});
}

/// 扫描确认弹窗
class ScanConfigDialog extends StatelessWidget {
  final String folderPath;

  const ScanConfigDialog({super.key, required this.folderPath});

  /// 显示扫描确认弹窗
  static Future<ScanConfigResult?> show(
    BuildContext context,
    String folderPath,
  ) async {
    final result = await showDialog<ScanConfigResult>(
      context: context,
      builder: (context) => ScanConfigDialog(folderPath: folderPath),
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      title: const Text('确认扫描'),
      contentPadding: const EdgeInsets.all(20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '即将扫描以下文件夹中的所有图片：',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : theme.hintColor,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withAlpha(8)
                  : theme.primaryColor.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.folder_open, size: 16,
                    color: isDark ? Colors.white70 : theme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    folderPath,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : theme.primaryColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '扫描使用多核并行计算，自动适配 CPU 核心数。',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : theme.hintColor,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(
              context, ScanConfigResult(confirmed: false)),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(
              context, ScanConfigResult(confirmed: true)),
          child: const Text('开始扫描'),
        ),
      ],
    );
  }
}
