// ============================================================
// lib/src/services/service_manual.dart
// 使用手册服务：
//   - 从 assets 加载 USER_MANUAL.md
//   - 首次运行时把手册拷贝到「可执行文件同目录」(Windows 下即安装目录)
//     → 用户在资源管理器中打开安装文件夹即可看到 USER_MANUAL.md
// ============================================================

import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

class ManualService {
  static const String _assetPath = 'assets/USER_MANUAL.md';
  static const String _fileName = 'USER_MANUAL.md';

  /// 内存缓存（避免重复读 assets）
  String? _cached;

  /// 读取手册 Markdown 文本（首次从 assets，之后内存）
  Future<String> loadContent() async {
    if (_cached != null) return _cached!;
    _cached = await rootBundle.loadString(_assetPath);
    return _cached!;
  }

  /// 把手册拷贝到「可执行文件同目录」。
  /// 拷贝策略：
  ///   - 若目标文件已存在，且内容一致 → noop（避免每次启动写盘）
  ///   - 若不存在 / 内容不一致（用户升级了应用）→ 覆盖
  /// 返回最终的文件绝对路径（拷贝成功时）；失败返回 null。
  Future<String?> ensureInInstallDir() async {
    try {
      // 1) 解析可执行文件目录
      final exe = Platform.resolvedExecutable;
      final installDir = File(exe).parent.path;

      // 2) 读取 assets 内的最新内容
      final content = await loadContent();
      final target = File(p.join(installDir, _fileName));

      // 3) 比对：已存在且内容相同 → 跳过
      if (await target.exists()) {
        final existing = await target.readAsString();
        if (existing == content) {
          return target.path;
        }
      }

      // 4) 写入
      await target.writeAsString(content, flush: true);
      return target.path;
    } catch (e) {
      // 安装目录可能没有写权限（例如 Program Files 管理员安装），
      // 这种情况下手册只通过应用内按钮查看即可。
      return null;
    }
  }
}
