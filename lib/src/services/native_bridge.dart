// ============================================================
// lib/src/services/native_bridge.dart
// 原生加速抽象层 — 仅条件导出 + 共享类型定义
//
// 编译期根据平台选择实现：
//   dart.library.io → native_bridge_ffi.dart (Rust FFI)
//   其他            → native_bridge_stub.dart (Dart fallback)
// ============================================================

import 'dart:typed_data';

// ─── 条件导出（必须在所有声明之前）───
export 'native_bridge_stub.dart'
    if (dart.library.io) 'native_bridge_ffi.dart';

// ─── 共享类型（两个实现共用的返回值类型）───

/// 单文件元数据（MD5 + EXIF + 文件信息）
class FileMetaResult {
  final String filePath;
  final String? md5hash;
  final Map<String, String>? exifAttrs;
  final int fileSize;
  final DateTime fileModified;

  const FileMetaResult({
    required this.filePath,
    this.md5hash,
    this.exifAttrs,
    required this.fileSize,
    required this.fileModified,
  });

  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'md5hash': md5hash,
        'exifAttrs': exifAttrs,
        'fileSize': fileSize,
        'fileModified': fileModified.toIso8601String(),
      };
}

/// 缩略图生成结果（与 rust/decoder.dart 的 ThumbnailResult 结构一致，
/// 但此文件不 import 生成代码以避免冲突）
class ThumbnailResult {
  final Uint8List jpegBytes;
  final int width;
  final int height;

  const ThumbnailResult({
    required this.jpegBytes,
    required this.width,
    required this.height,
  });
}
