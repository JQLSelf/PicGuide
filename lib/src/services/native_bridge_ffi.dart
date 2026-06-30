// ============================================================
// lib/src/services/native_bridge_ffi.dart
// Windows 桌面端 FFI 实现 — 通过 flutter_rust_bridge 调用 Rust DLL
//
// 注意：不要 import native_bridge.dart，避免类型冲突。
// 此文件直接使用 native_bridge.dart 定义的类型（通过 export 可用），
// 内部映射到 rust/ 生成的类型。
// ============================================================

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show debugPrint;
import '../rust/frb_generated.dart' show RustLib;
import '../rust/api.dart' as ffi;
import '../rust/batch.dart' as rust_batch;
import '../rust/decoder.dart' as rust_decoder;
import '../rust/exif.dart' as rust_exif;
import 'native_bridge.dart' show FileMetaResult, ThumbnailResult;

bool _initialized = false;

Future<void> _ensureInit() async {
  if (_initialized) return;
  try {
    await RustLib.init();
    _initialized = true;
    debugPrint('[Rust] FFI initialized');
  } catch (e) {
    debugPrint('[Rust] FFI init failed: $e');
    rethrow;
  }
}

bool get isNativeAvailable => true;

Future<String> nativeVersion() async {
  await _ensureInit();
  return await ffi.nativeVersion();
}

/// 释放 Rust 原生库
void disposeNative() {
  try {
    RustLib.dispose();
  } catch (e) {
    debugPrint('[Rust] dispose failed: $e');
  }
}

Future<List<FileMetaResult>> processFileBatch({
  required List<String> paths,
}) async {
  await _ensureInit();
  final results = await ffi.processFileBatch(paths: paths);
  return results.map((r) => FileMetaResult(
    filePath: r.filePath,
    md5hash: r.md5,
    exifAttrs: _exifToMap(r.exif),
    fileSize: r.fileSize.toInt(),
    fileModified:
        DateTime.fromMillisecondsSinceEpoch(r.fileModifiedSecs * 1000),
  )).toList();
}

Future<ThumbnailResult?> makeThumbnail({
  required String path,
  required int maxW,
  required int maxH,
  required int quality,
}) async {
  await _ensureInit();
  final result = await ffi.makeThumbnail(
    path: path,
    maxW: maxW,
    maxH: maxH,
    quality: quality,
  );
  if (result == null) return null;
  return ThumbnailResult(
    jpegBytes: result.jpegBytes,
    width: result.width,
    height: result.height,
  );
}

Map<String, String> _exifToMap(rust_exif.ExifData? exif) {
  if (exif == null) return {};
  final map = <String, String>{};
  void a(String k, Object? v) { if (v != null) map[k] = v.toString(); }
  a('DateTimeOriginal', exif.dateTaken);
  a('Make', exif.make);
  a('Model', exif.model);
  a('ISOSpeedRatings', exif.iso);
  a('FNumber', exif.fNumber);
  a('ExposureTime', exif.exposure);
  a('FocalLength', exif.focal);
  a('GPSLatitude', exif.lat);
  a('GPSLongitude', exif.lng);
  a('ExifImageWidth', exif.imageWidth);
  a('ExifImageLength', exif.imageHeight);
  a('Orientation', exif.orientation);
  return map;
}
