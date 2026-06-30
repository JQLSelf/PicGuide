// ============================================================
// lib/src/services/native_bridge_stub.dart
// Dart 兜底实现（非 Windows 平台）
//
// 委托现有 Dart 库：
//   - helper_md5.dart      → MD5 计算
//   - service_exif_reader.dart → EXIF 解析
//   - package:image        → 图片解码/缩放/编码
//
// 与 native_bridge_ffi.dart 保持完全相同的函数签名。
// ============================================================

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'native_bridge.dart';
import 'helper_md5.dart';
import 'service_exif_reader.dart';

// ─── 批量文件处理 ───

/// 批量处理文件（MD5 + EXIF + stat）
///
/// 返回顺序与 paths 一致。
Future<List<FileMetaResult>> processFileBatch({
  required List<String> paths,
}) async {
  final results = <FileMetaResult>[];
  for (final path in paths) {
    results.add(await _computeOne(path));
  }
  return results;
}

/// 单个文件元数据计算（与 _computeFileMeta 逻辑一致）
Future<FileMetaResult> _computeOne(String filePath) async {
  final file = File(filePath);
  FileStat stat;
  try {
    stat = await file.stat();
  } catch (_) {
    return FileMetaResult(
      filePath: filePath,
      fileSize: 0,
      fileModified: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  String? md5hash;
  try {
    md5hash = await Md5Helper.compute(filePath);
  } catch (_) {}

  Map<String, String>? exifAttrs;
  try {
    final tags = await readJpegExif(filePath);
    if (tags != null) {
      exifAttrs = {};
      exifAttrs.addAll(tags.attrs);
      exifAttrs.addAll(tags.exif);
      exifAttrs.addAll(tags.gps);
    }
  } catch (_) {}

  return FileMetaResult(
    filePath: filePath,
    md5hash: md5hash,
    exifAttrs: exifAttrs,
    fileSize: stat.size,
    fileModified: stat.modified,
  );
}

// ─── 缩略图生成 ───

/// 在 Isolate 中解码图片
img.Image? _decodeImageIsolate(Uint8List bytes) {
  return img.decodeImage(bytes);
}

/// 生成缩略图（与 _generateThumbnailInner 逻辑一致）
///
/// 返回 JPEG 压缩后的字节数组。
/// 注意：当前实现先读全文件再解码，内存峰值高（会被 Rust libjpeg-turbo 解决）。
Future<ThumbnailResult?> makeThumbnail({
  required String path,
  required int maxW,
  required int maxH,
  required int quality,
}) async {
  try {
    final file = File(path);
    final bytes = await file.readAsBytes();
    final image = await compute(_decodeImageIsolate, bytes);
    if (image == null) return null;

    img.Image thumbnail;
    final needsWidthResize = image.width > maxW;
    final needsHeightResize = image.height > maxH;

    if (needsWidthResize || needsHeightResize) {
      thumbnail = img.copyResize(
        image,
        width: needsWidthResize ? maxW : null,
        height: needsHeightResize ? maxH : null,
      );
    } else {
      thumbnail = image;
    }

    final jpegBytes = Uint8List.fromList(
      img.encodeJpg(thumbnail, quality: quality),
    );

    return ThumbnailResult(
      jpegBytes: jpegBytes,
      width: thumbnail.width,
      height: thumbnail.height,
    );
  } catch (e) {
    debugPrint('[native_bridge_stub] makeThumbnail failed: $e');
    return null;
  }
}

// ─── 兜底元数据 ───

/// 是否原生加速可用（stub 始终返回 false）
bool get isNativeAvailable => false;

/// 原生库版本（stub 无版本号）
Future<String> nativeVersion() async => 'dart-stub';

/// 原生库释放（stub 无需处理）
void disposeNative() {}
