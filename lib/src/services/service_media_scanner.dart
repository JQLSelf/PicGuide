// ============================================================
// lib/src/services/service_media_scanner.dart
// 媒体扫描：MD5 去重 + EXIF 提取 + 数据库归档 + 缩略图缓存
// 使用 Isolate 真并行计算，充分利用多核 CPU
// ============================================================
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:drift/drift.dart';
import 'package:native_exif/native_exif.dart';
import 'package:geocoding/geocoding.dart';
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import '../db/database.dart';
import 'service_exif_reader.dart';
import 'helper_md5.dart';
import 'service_region_resolver.dart';
import 'helper_path.dart';
import 'service_scan_controller.dart';

const _imageExts = {
  '.jpg',
  '.jpeg',
  '.png',
  '.webp',
  '.bmp',
  '.gif',
  '.tiff',
  '.tif',
  '.heic',
  '.heif',
  '.avif',
  '.raw',
  '.cr2',
  '.nef',
  '.arw',
  '.dng',
};

// ─────────────────────────────────────────────
// 数据模型
// ─────────────────────────────────────────────

enum ScanPhase {
  indexing, // 正在索引文件（MD5 + EXIF + 入库）
  reconciling, // 正在对账（标记磁盘已删除的文件）
  generatingThumbnails, // 正在补生成缩略图
}

class ScanProgress {
  final int current;
  final int total;
  final String currentFile;
  final int added;
  final int duplicates;
  final int updated;
  final double speed; // 文件/秒
  final Duration? eta; // 预估剩余时间
  final ScanPhase phase;

  const ScanProgress({
    required this.current,
    required this.total,
    required this.currentFile,
    this.added = 0,
    this.duplicates = 0,
    this.updated = 0,
    this.speed = 0.0,
    this.eta,
    this.phase = ScanPhase.indexing,
  });

  /// 进度百分比 (0.0 ~ 1.0)
  double get ratio => total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;

  /// 格式化的速度描述
  String get speedLabel {
    if (speed < 1) return '${(speed * 60).toStringAsFixed(1)} 个/分钟';
    return '${speed.toStringAsFixed(1)} 个/秒';
  }

  /// 格式化的剩余时间
  String get etaLabel {
    final e = eta;
    if (e == null) return '';
    if (e.inSeconds < 60) return '${e.inSeconds}秒';
    if (e.inMinutes < 60) return '${e.inMinutes}分${e.inSeconds % 60}秒';
    return '${e.inHours}小时${e.inMinutes % 60}分';
  }
}

class ScanSummary {
  final int added;
  final int duplicates;
  final int updated;
  final int missing;
  const ScanSummary({
    required this.added,
    required this.duplicates,
    required this.updated,
    required this.missing,
  });
}

class ThumbnailOptions {
  final int quality;
  final int maxWidth;
  final int maxHeight;
  const ThumbnailOptions({
    this.quality = 60,
    this.maxWidth = 200,
    this.maxHeight = 200,
  });
}

/// Isolate 计算结果：单个文件的 MD5 + EXIF 元数据
class _FileMetaResult {
  final String filePath;
  final String? md5hash;
  final Map<String, String>? exifAttrs;
  final int fileSize;
  final DateTime? fileModified;
  const _FileMetaResult({
    required this.filePath,
    this.md5hash,
    this.exifAttrs,
    required this.fileSize,
    this.fileModified,
  });
}

// ─────────────────────────────────────────────
// Isolate 顶层函数（必须为顶层函数，供 compute() 调用）
// ─────────────────────────────────────────────

/// 在独立 Isolate 中计算单个文件的 MD5 + EXIF
/// CPU 密集操作（MD5 哈希 + JPEG EXIF 解析）在 Isolate 中执行，
/// 不阻塞主 isolate 的 UI 线程。
Future<_FileMetaResult> _computeFileMeta(String filePath) async {
  final file = File(filePath);
  FileStat? stat;
  try {
    stat = await file.stat();
  } catch (_) {
    return _FileMetaResult(filePath: filePath, fileSize: 0);
  }

  // MD5 计算（CPU 密集）
  String? md5hash;
  try {
    md5hash = await Md5Helper.compute(filePath);
  } catch (_) {}

  // EXIF 解析（纯 Dart 实现，在 Isolate 中可用）
  Map<String, String>? exifAttrs;
  try {
    final tags = await readJpegExif(filePath);
    if (tags != null) {
      exifAttrs = Map<String, String>.from(tags.attrs);
    }
  } catch (_) {}

  return _FileMetaResult(
    filePath: filePath,
    md5hash: md5hash,
    exifAttrs: exifAttrs,
    fileSize: stat.size,
    fileModified: stat.modified,
  );
}

// ─────────────────────────────────────────────
// MediaScanner
// ─────────────────────────────────────────────

class MediaScanner {
  final AppDatabase _db;

  /// 预加载的数据库记录（避免逐条查询）
  final Map<String, MediaItem> _pathMap = {};
  final Set<String> _md5Set = {};

  /// 缩略图生成信号量（最多同时 2 个解码，防止内存撑爆）
  final _thumbSemaphore = _Semaphore(2);

  MediaScanner(this._db);

  /// 扫描文件夹并归档到数据库
  /// - 使用 Isolate 真并行：MD5 + EXIF 在独立线程计算
  /// - 并发数自动适配 CPU 核心数（2~8）
  /// - 已有记录用 MD5 命中 → 仅刷新路径/mtime/size/md5，EXIF 重新提取
  /// - 全新记录 → 完整入库
  /// - 扫描末尾对账：标记磁盘已不存在的记录
  Stream<ScanProgress> scanFolder(
    String folderPath, {
    ScanController? controller,
  }) async* {
    controller?.reset();
    controller?.updateState(ScanState.scanning);

    final concurrency = Platform.numberOfProcessors.clamp(2, 8);
    final scanStartTime = DateTime.now();
    debugPrint('🚀 开始扫描: $folderPath (Isolate 并行, $concurrency workers)');

    final dir = Directory(folderPath);
    if (!await dir.exists()) return;

    // ── 批量预加载：一次性加载文件夹下所有已知记录 ──
    _pathMap.clear();
    _md5Set.clear();
    try {
      final existingItems = await _db.getItemsByFolderPrefix(folderPath);
      for (final item in existingItems) {
        _pathMap[item.filePath] = item;
        if (item.md5 != null && item.md5!.isNotEmpty) {
          _md5Set.add(item.md5!);
        }
      }
      debugPrint('📦 预加载 ${_pathMap.length} 条记录，'
          '${_md5Set.length} 个 MD5（避免逐条 DB 查询）');
    } catch (e) {
      debugPrint('⚠️ 预加载失败，将回退到逐条查询: $e');
    }

    // 收集所有图片文件
    final files = <File>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (controller?.shouldStop() ?? false) break;
      if (entity is File) {
        final ext = p.extension(entity.path).toLowerCase();
        if (_imageExts.contains(ext)) {
          files.add(entity);
        }
      }
    }

    if (files.isEmpty) {
      controller?.complete();
      return;
    }

    debugPrint('📁 找到 ${files.length} 个图片文件');

    int processedCount = 0;
    int added = 0;
    int duplicates = 0;
    int updated = 0;

    // 分批处理，每批 concurrency 个文件并行计算
    for (var i = 0; i < files.length; i += concurrency) {
      if (_shouldAbort(controller)) break;
      await controller?.checkPause();
      if (_shouldAbort(controller)) break;

      final batchEnd = (i + concurrency).clamp(0, files.length);
      final batch = files.sublist(i, batchEnd);

      // Phase 1: 在 Isolate 中并行计算 MD5 + EXIF（CPU 密集）
      final metaFutures =
          batch.map((file) => compute(_computeFileMeta, file.path)).toList();
      final metaResults = await Future.wait(metaFutures);

      // Phase 2: 主 isolate 处理数据库操作 + GPS 反查（I/O 密集）
      for (var j = 0; j < batch.length; j++) {
        if (_shouldAbort(controller)) break;

        final file = batch[j];
        final meta = metaResults[j];
        processedCount++;

        // 计算速度和 ETA
        final elapsed = DateTime.now().difference(scanStartTime).inSeconds;
        final speed = elapsed > 0 ? processedCount / elapsed : 0.0;
        Duration? eta;
        if (speed > 0) {
          final remaining = files.length - processedCount;
          eta = Duration(seconds: (remaining / speed).round());
        }

        yield ScanProgress(
          current: processedCount,
          total: files.length,
          currentFile: p.basename(file.path),
          added: added,
          duplicates: duplicates,
          updated: updated,
          speed: speed,
          eta: eta,
          phase: ScanPhase.indexing,
        );

        try {
          await _indexFileWithMeta(file, meta,
              forceReindexExif: true, controller: controller);
          added++;
        } on StateError catch (_) {
          if (controller?.shouldStop() ?? false) break;
          duplicates++;
        } catch (e) {
          debugPrint('❌ 处理文件失败: ${file.path} - $e');
          duplicates++;
        }
      }
    }

    // 对账阶段
    if (!(controller?.shouldStop() ?? false)) {
      yield ScanProgress(
        current: files.length,
        total: files.length,
        currentFile: '正在对账...',
        added: added,
        duplicates: duplicates,
        updated: updated,
        phase: ScanPhase.reconciling,
      );
      await _performReconciliation(folderPath, files.length, controller);
    }

    controller?.complete();
    debugPrint('✅ 扫描完成');
  }

  /// 扫描单个文件（公开，供"导入单文件"使用）
  Future<MediaItem> indexSingleFile(String filePath) async {
    final f = File(filePath);
    if (!await f.exists()) {
      throw FileSystemException('文件不存在', filePath);
    }
    return _indexFile(f);
  }

  // ─────────────────────────────────────────────
  // 核心索引方法
  // ─────────────────────────────────────────────

  /// 通用索引：先按 filePath → 再按 MD5 查重。
  /// 用于单文件导入场景（不走 Isolate，单文件无需并行）。
  Future<MediaItem> _indexFile(File file,
      {bool forceReindexExif = false, ScanController? controller}) async {
    if (controller?.shouldStop() ?? false) {
      throw StateError('扫描已停止');
    }

    final stat = await file.stat();

    if (controller?.shouldStop() ?? false) {
      throw StateError('扫描已停止');
    }

    final ext = p.extension(file.path).toLowerCase();
    final isImage = _imageExts.contains(ext);
    final path = file.path;

    // 1) 先按 filePath 查
    var existing = await _db.findByPath(path);

    // 2) 算 MD5
    String md5hash = '';
    try {
      md5hash = await Md5Helper.compute(path);
    } catch (e) {
      debugPrint('md5 error: $path - $e');
    }

    if (controller?.shouldStop() ?? false) {
      throw StateError('扫描已停止');
    }

    // 3) 跨位置去重
    if (existing == null && md5hash.isNotEmpty) {
      existing = await _db.findByMd5(md5hash);
    }

    if (existing != null) {
      if (controller?.shouldStop() ?? false) {
        throw StateError('扫描已停止');
      }

      await _db.updateMedia(
          existing.id,
          MediaItemsCompanion(
            filePath: Value(path),
            fileName: Value(p.basename(path)),
            fileType: Value('image'),
            mimeType: Value(_mimeType(ext)),
            fileSizeBytes: Value(stat.size),
            fileModifiedAt: Value(stat.modified),
            indexedAt: Value(DateTime.now()),
            md5: Value(md5hash),
            isDeleted: const Value(false),
            isMissing: const Value(false),
          ));

      if (controller?.shouldStop() ?? false) {
        throw StateError('扫描已停止');
      }

      if (isImage) {
        await _extractAndSaveExif(file, existing.id,
            overwrite: forceReindexExif);
      }
      if (existing.thumbnailPath == null) {
        if (controller?.shouldStop() ?? false) {
          throw StateError('扫描已停止');
        }
        final thumbPath = await generateThumbnail(file, existing.id.toString());
        if (thumbPath != null) {
          await _db.updateMedia(existing.id,
              MediaItemsCompanion(thumbnailPath: Value(thumbPath)));
        }
      }
      return existing;
    }

    // 全新入库
    String? thumbPath;
    try {
      if (controller?.shouldStop() ?? false) {
        throw StateError('扫描已停止');
      }
      thumbPath = await generateThumbnail(
          file, md5hash.isNotEmpty ? md5hash : path.hashCode.toString());
    } catch (e) {
      debugPrint('thumbnail error: $path - $e');
    }

    if (controller?.shouldStop() ?? false) {
      throw StateError('扫描已停止');
    }

    await _db.upsertMediaItem(MediaItemsCompanion.insert(
      filePath: path,
      fileName: p.basename(path),
      fileType: 'image',
      mimeType: Value(_mimeType(ext)),
      fileSizeBytes: Value(stat.size),
      fileModifiedAt: Value(stat.modified),
      indexedAt: Value(DateTime.now()),
      md5: Value(md5hash),
      isDeleted: const Value(false),
      isMissing: const Value(false),
      thumbnailPath: Value(thumbPath),
    ));

    if (controller?.shouldStop() ?? false) {
      throw StateError('扫描已停止');
    }

    final saved = await _db.findByPath(path);
    if (saved != null && isImage) {
      await _extractAndSaveExif(file, saved.id);
    }
    return saved ?? (throw StateError('保存失败: $path'));
  }

  /// 批量索引：使用 Isolate 预计算的元数据
  /// MD5 + EXIF 已在 Isolate 中算好，这里只做 DB 操作 + GPS 反查
  /// 优先使用内存预加载数据（_pathMap / _md5Set），避免逐条 DB 查询
  Future<MediaItem> _indexFileWithMeta(
    File file,
    _FileMetaResult meta, {
    bool forceReindexExif = false,
    ScanController? controller,
  }) async {
    if (controller?.shouldStop() ?? false) {
      throw StateError('扫描已停止');
    }

    final ext = p.extension(file.path).toLowerCase();
    final isImage = _imageExts.contains(ext);
    final path = file.path;
    final md5hash = meta.md5hash ?? '';

    // 1) 先按 filePath 查内存（命中则跳过 DB 查询）
    MediaItem? existing = _pathMap[path];
    if (existing == null) {
      // 内存未命中，回退到 DB 查询
      existing = await _db.findByPath(path);
      if (existing != null) _pathMap[path] = existing;
    }

    if (controller?.shouldStop() ?? false) {
      throw StateError('扫描已停止');
    }

    // 2) 跨位置去重（MD5 已在 Isolate 中算好）
    if (existing == null && md5hash.isNotEmpty) {
      if (_md5Set.contains(md5hash)) {
        // MD5 命中但路径未命中 → 需要查 DB 找到那个记录
        existing = await _db.findByMd5(md5hash);
        if (existing != null) _pathMap[existing.filePath] = existing;
      }
    }

    if (existing != null) {
      if (controller?.shouldStop() ?? false) {
        throw StateError('扫描已停止');
      }

      await _db.updateMedia(
          existing.id,
          MediaItemsCompanion(
            filePath: Value(path),
            fileName: Value(p.basename(path)),
            fileType: Value('image'),
            mimeType: Value(_mimeType(ext)),
            fileSizeBytes: Value(meta.fileSize),
            fileModifiedAt: Value(meta.fileModified ?? DateTime.now()),
            indexedAt: Value(DateTime.now()),
            md5: Value(md5hash),
            isDeleted: const Value(false),
            isMissing: const Value(false),
          ));

      if (controller?.shouldStop() ?? false) {
        throw StateError('扫描已停止');
      }

      // 使用 Isolate 预计算的 EXIF 数据（跳过文件读取）
      if (isImage && meta.exifAttrs != null && meta.exifAttrs!.isNotEmpty) {
        await _saveExifAttrs(meta.exifAttrs!, existing.id,
            overwrite: forceReindexExif);
      }

      if (existing.thumbnailPath == null) {
        if (controller?.shouldStop() ?? false) {
          throw StateError('扫描已停止');
        }
        final thumbPath =
            await _thumbWithSemaphore(file, existing.id.toString());
        if (thumbPath != null) {
          await _db.updateMedia(existing.id,
              MediaItemsCompanion(thumbnailPath: Value(thumbPath)));
        }
      }
      return existing;
    }

    // 全新入库
    String? thumbPath;
    try {
      if (controller?.shouldStop() ?? false) {
        throw StateError('扫描已停止');
      }
      thumbPath = await _thumbWithSemaphore(
          file, md5hash.isNotEmpty ? md5hash : path.hashCode.toString());
    } catch (e) {
      debugPrint('thumbnail error: $path - $e');
    }

    if (controller?.shouldStop() ?? false) {
      throw StateError('扫描已停止');
    }

    await _db.upsertMediaItem(MediaItemsCompanion.insert(
      filePath: path,
      fileName: p.basename(path),
      fileType: 'image',
      mimeType: Value(_mimeType(ext)),
      fileSizeBytes: Value(meta.fileSize),
      fileModifiedAt: Value(meta.fileModified ?? DateTime.now()),
      indexedAt: Value(DateTime.now()),
      md5: Value(md5hash),
      isDeleted: const Value(false),
      isMissing: const Value(false),
      thumbnailPath: Value(thumbPath),
    ));

    if (controller?.shouldStop() ?? false) {
      throw StateError('扫描已停止');
    }

    final saved = await _db.findByPath(path);
    if (saved != null) {
      // 更新内存索引，避免后续文件重复查询
      _pathMap[path] = saved;
      if (md5hash.isNotEmpty) _md5Set.add(md5hash);
      if (isImage && meta.exifAttrs != null) {
        await _saveExifAttrs(meta.exifAttrs!, saved.id);
      }
    }
    return saved ?? (throw StateError('保存失败: $path'));
  }

  // ─────────────────────────────────────────────
  // EXIF 处理
  // ─────────────────────────────────────────────

  /// 提取并保存 EXIF（从文件读取，用于单文件导入）
  Future<void> _extractAndSaveExif(File file, int mediaId,
      {bool overwrite = false}) async {
    try {
      final attrs = await _readExifAttrs(file.path);
      if (attrs.isEmpty) return;
      await _saveExifAttrs(attrs, mediaId, overwrite: overwrite);
    } catch (e) {
      debugPrint('exif error: $e');
    }
  }

  /// 保存 EXIF 数据到数据库（可接受预计算的 attrs）
  /// GPS 反查在主 isolate 执行（需要 RegionResolver + geocoding）
  Future<void> _saveExifAttrs(
    Map<String, String> attrs,
    int mediaId, {
    bool overwrite = false,
  }) async {
    try {
      if (attrs.isEmpty) return;

      final lat = _parseGpsCoord(attrs['GPSLatitude'], attrs['GPSLatitudeRef']);
      final lng =
          _parseGpsCoord(attrs['GPSLongitude'], attrs['GPSLongitudeRef']);

      // 离线 RegionResolver + 在线兜底
      String? cityName;
      String? province;
      String? district;
      if (lat != null && lng != null) {
        await RegionResolver.instance.load();
        final info = RegionResolver.instance.resolve(lat, lng);
        if (info != null) {
          province = info.province;
          cityName = info.city;
          district = info.district;
        } else {
          final fallback = await _reverseGeocode(lat, lng);
          if (fallback.cityName != null) cityName = fallback.cityName;
          province = fallback.province;
          district = fallback.city;
        }
      }

      final dateTaken = _parseExifDate(attrs['DateTimeOriginal']);

      if (overwrite) {
        await (_db.delete(_db.exifDatas)
              ..where((e) => e.mediaItemId.equals(mediaId)))
            .go();
      }

      await _db.upsertExif(ExifDatasCompanion.insert(
        mediaItemId: mediaId,
        make: Value(attrs['Make']),
        model: Value(attrs['Model']),
        software: Value(attrs['Software']),
        dateTaken: Value(dateTaken),
        latitude: Value(lat),
        longitude: Value(lng),
        cityName: Value(cityName),
        province: Value(province),
        district: Value(district),
        isoSpeed: Value(attrs['ISOSpeedRatings']),
        fNumber: Value(attrs['FNumber']),
        exposureTime: Value(attrs['ExposureTime']),
        focalLength: Value(attrs['FocalLength']),
        imageWidth: Value(int.tryParse(attrs['ExifImageWidth'] ?? '')),
        imageHeight: Value(int.tryParse(attrs['ExifImageLength'] ?? '')),
        orientation: Value(attrs['Orientation']),
        rawJson: Value(_safeJson(attrs)),
      ));
    } catch (e) {
      debugPrint('exif error: $e');
    }
  }

  /// 多平台 EXIF 读取：
  /// 1) 优先 native_exif（iOS/Android 上由系统库读取）
  /// 2) 失败/空 → 用自研纯 Dart 解析器（覆盖 Windows/macOS/Linux）
  Future<Map<String, String>> _readExifAttrs(String path) async {
    Map<String, String> result = {};
    final isMobile = Platform.isIOS || Platform.isAndroid;
    if (isMobile) {
      try {
        final exif = await Exif.fromPath(path);
        final attrs = await exif.getAttributes();
        await exif.close();
        if (attrs != null) {
          attrs.forEach((k, v) => result[k.toString()] = v.toString());
        }
      } catch (e) {
        debugPrint('native_exif failed, fallback to dart: $path - $e');
      }
    }
    if (result.isEmpty) {
      final dartResult = await readJpegExif(path);
      if (dartResult != null) {
        result = Map<String, String>.from(dartResult.attrs);
      }
    }
    return result;
  }

  // ─────────────────────────────────────────────
  // 缩略图
  // ─────────────────────────────────────────────

  /// 生成缩略图并保存到缓存目录
  /// 通过信号量限制并发数，防止大图同时解码撑爆内存
  Future<String?> generateThumbnail(
    File file,
    String mediaId, {
    ThumbnailOptions? options,
  }) async {
    return _thumbWithSemaphore(file, mediaId, options: options);
  }

  /// 带信号量保护的缩略图生成
  Future<String?> _thumbWithSemaphore(
    File file,
    String mediaId, {
    ThumbnailOptions? options,
  }) async {
    await _thumbSemaphore.acquire();
    try {
      return await _generateThumbnailInner(file, mediaId, options: options);
    } finally {
      _thumbSemaphore.release();
    }
  }

  /// 缩略图生成内部实现
  Future<String?> _generateThumbnailInner(
    File file,
    String mediaId, {
    ThumbnailOptions? options,
  }) async {
    try {
      final quality = options?.quality ?? 60;
      final maxWidth = options?.maxWidth ?? 200;
      final maxHeight = options?.maxHeight ?? 200;

      final thumbPath =
          PathHelper.instance.generateThumbnailPath(mediaId, '.jpg');

      final bytes = await file.readAsBytes();
      final image = await compute(_decodeImageIsolate, bytes);
      if (image == null) return null;

      img.Image? thumbnail;
      final needsWidthResize = image.width > maxWidth;
      final needsHeightResize = image.height > maxHeight;

      if (needsWidthResize || needsHeightResize) {
        thumbnail = img.copyResize(
          image,
          width: needsWidthResize ? maxWidth : null,
          height: needsHeightResize ? maxHeight : null,
        );
      } else {
        thumbnail = image;
      }

      final compressed = img.encodeJpg(thumbnail, quality: quality);
      await File(thumbPath).writeAsBytes(compressed);

      return thumbPath;
    } catch (e) {
      debugPrint('generateThumbnail failed: $e');
      return null;
    }
  }

  /// 补全所有缺失的缩略图（全库对账时调用）
  Future<int> generateMissingThumbnails() async {
    final query = _db.select(_db.mediaItems)
      ..where((t) => t.isDeleted.equals(false))
      ..where((t) => t.isMissing.equals(false));
    final items = await query.get();

    int count = 0;
    for (final item in items) {
      bool needGenerate = false;
      if (item.thumbnailPath == null) {
        needGenerate = true;
      } else {
        final thumbFile = File(item.thumbnailPath!);
        needGenerate = !await thumbFile.exists();
      }

      if (needGenerate) {
        final file = File(item.filePath);
        if (await file.exists()) {
          final mediaId =
              (item.md5?.isNotEmpty ?? false) ? item.md5! : item.id.toString();
          final thumbPath = await generateThumbnail(file, mediaId);
          if (thumbPath != null) {
            await _db.updateMedia(
                item.id, MediaItemsCompanion(thumbnailPath: Value(thumbPath)));
            count++;
          }
        }
      }
    }
    return count;
  }

  // ─────────────────────────────────────────────
  // 区域分析
  // ─────────────────────────────────────────────

  /// 全库重新分析区域
  Future<int> reAnalyzeAllRegions() async {
    await RegionResolver.instance.load();
    return _db.reAnalyzeRegions((lat, lng) async {
      final info = RegionResolver.instance.resolve(lat, lng);
      if (info == null) {
        final fb = await _reverseGeocode(lat, lng);
        return (
          province: fb.province,
          city: fb.city,
          district: null,
          cityName: fb.cityName,
        );
      }
      return (
        province: info.province,
        city: info.city,
        district: info.district,
        cityName: info.city,
      );
    });
  }

  // ─────────────────────────────────────────────
  // 工具方法
  // ─────────────────────────────────────────────

  double? _parseGpsCoord(dynamic coord, dynamic ref) {
    if (coord == null) return null;
    try {
      double value;
      if (coord is double) {
        value = coord;
      } else {
        final parts = coord.toString().split(',');
        if (parts.length != 3) return null;

        double parseDeg(String s) {
          final nd = s.split('/');
          if (nd.length == 2) {
            return double.parse(nd[0]) / double.parse(nd[1]);
          }
          return double.parse(s);
        }

        final deg = parseDeg(parts[0]);
        final min = parseDeg(parts[1]);
        final sec = parseDeg(parts[2]);
        value = deg + min / 60 + sec / 3600;
      }
      if (ref == 'S' || ref == 'W') value = -value;
      return value;
    } catch (_) {
      return null;
    }
  }

  DateTime? _parseExifDate(String? raw) {
    if (raw == null) return null;
    try {
      final normalized = raw.replaceFirst(':', '-').replaceFirst(':', '-');
      return DateTime.parse(normalized);
    } catch (_) {
      return null;
    }
  }

  String? _safeJson(Map<String, String> attrs) {
    try {
      return attrs.entries.map((e) => '"${e.key}":"${e.value}"').join(',');
    } catch (_) {
      return null;
    }
  }

  String _mimeType(String ext) {
    const map = {
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.png': 'image/png',
      '.webp': 'image/webp',
      '.gif': 'image/gif',
      '.bmp': 'image/bmp',
      '.heic': 'image/heic',
    };
    return map[ext] ?? 'application/octet-stream';
  }

  bool _shouldAbort(ScanController? controller) {
    return controller?.shouldStop() ?? false;
  }

  /// 在线 geocoding 兜底
  Future<({String? province, String? city, String? cityName})> _reverseGeocode(
      double lat, double lng) async {
    final existing = await (_db.select(_db.exifDatas)
          ..where((e) => e.latitude.isBiggerOrEqualValue(lat - 0.5))
          ..where((e) => e.latitude.isSmallerOrEqualValue(lat + 0.5))
          ..where((e) => e.longitude.isBiggerOrEqualValue(lng - 0.5))
          ..where((e) => e.longitude.isSmallerOrEqualValue(lng + 0.5))
          ..where((e) => e.cityName.isNotNull()))
        .getSingleOrNull();
    if (existing?.cityName != null && existing!.cityName!.isNotEmpty) {
      return (province: null, city: null, cityName: existing.cityName);
    }
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final pm = placemarks.first;
        final parts = [pm.locality, pm.administrativeArea, pm.country]
            .where((s) => s != null && s.isNotEmpty);
        return (
          province: pm.administrativeArea,
          city: pm.locality,
          cityName: parts.join(', '),
        );
      }
    } catch (e) {
      debugPrint('geocoding error: $e');
    }
    return (province: null, city: null, cityName: null);
  }

  /// 执行对账操作
  Future<void> _performReconciliation(
    String folderPath,
    int fileCount,
    ScanController? controller,
  ) async {
    if (_shouldAbort(controller)) return;

    try {
      final missing = await _db.markMissingInFolder(folderPath);

      await _db.into(_db.folderScans).insert(
            FolderScansCompanion.insert(
              folderPath: folderPath,
              lastScannedAt: Value(DateTime.now()),
              itemCount: Value(fileCount),
              missingCount: Value(missing),
            ),
            onConflict: DoUpdate(
              (old) => FolderScansCompanion(
                lastScannedAt: Value(DateTime.now()),
                itemCount: Value(fileCount),
                missingCount: Value(missing),
              ),
              target: [_db.folderScans.folderPath],
            ),
          );

      debugPrint('📊 对账完成：缺失 $missing 个文件');
    } catch (e) {
      debugPrint('❌ 对账失败: $e');
    }
  }
}

/// 简单信号量：限制并发异步操作数量，防止内存撑爆
class _Semaphore {
  final int maxCocurrent;
  int _active = 0;
  final _queue = <Completer<void>>[];

  _Semaphore(this.maxCocurrent);

  /// 获取许可（达到上限时等待，零 CPU 忙等）
  Future<void> acquire() async {
    if (_active < maxCocurrent) {
      _active++;
      return;
    }
    final completer = Completer<void>();
    _queue.add(completer);
    await completer.future;
  }

  /// 释放许可
  void release() {
    _active--;
    if (_queue.isNotEmpty) {
      final next = _queue.removeAt(0);
      _active++;
      next.complete();
    }
  }
}

/// Isolate 入口：解码图片字节
img.Image? _decodeImageIsolate(Uint8List bytes) {
  return img.decodeImage(bytes);
}

void debugPrint(String msg) {
  // ignore: avoid_print
  print('[PixelVault] $msg');
}
