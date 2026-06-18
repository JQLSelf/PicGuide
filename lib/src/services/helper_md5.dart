// ============================================================
// lib/src/services/helper_md5.dart
// 文件 MD5 计算（小文件用全量读，大文件用流式分块）
// ============================================================
import 'dart:io';
import 'package:crypto/crypto.dart';

class Md5Helper {
  /// 完整读取并算 MD5（适合图片）。
  /// 大文件（> 200MB）会走流式分块以避免内存爆掉。
  static Future<String> compute(String filePath) async {
    final file = File(filePath);
    final size = await file.length();
    if (size < 200 * 1024 * 1024) {
      final bytes = await file.readAsBytes();
      return md5.convert(bytes).toString();
    }
    // 流式：8MB / 块
    final digest = await md5.bind(file.openRead()).first;
    return digest.toString();
  }
}
