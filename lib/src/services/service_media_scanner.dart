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
import 'native_bridge.dart';

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

const _videoExts = {
  '.mp4',
  '.mov',
  '.avi',
  '.mkv',
  '.wmv',
  '.webm',
  '.m4v',
  '.flv',
  '.mts',   // MPEG Transport Stream（摄像机常用）
  '.3gp',
};

// ─────────────────────────────────────────────
// 数据模型
// ─────────────────────────────────────────────

enum ScanPhase {
  indexing, // 正在索引文件（MD5 + EXIF + 入库）
  reconciling, // 正在对账（标记磁盘已删除的文件）
  rebuildingIndex, // 正在重建时间轴索引
  generatingThumbnails, // 正在补生成缩略图
  generatingVideoCovers, // 正在生成视频封面（Phase B）
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

/// 在独立 Isolate 中批量处理文件（MD5 + EXIF）
/// 通过 native_bridge 调用 Rust FFI 或 Dart 兜底，不阻塞主 Isolate。
Future<List<_FileMetaResult>> _processBatchInIsolate(List<String> paths) async {
  try {
    final results = await processFileBatch(paths: paths);
    return results.map((r) => _FileMetaResult(
      filePath: r.filePath,
      md5hash: r.md5hash,
      exifAttrs: r.exifAttrs,
      fileSize: r.fileSize,
      fileModified: r.fileModified,
    )).toList();
  } catch (_) {
    // 兜底：逐个文件用 Isolate
    return Future.wait(
      paths.map((p) => _computeFileMeta(p)),
    );
  }
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

    // 收集所有图片与视频文件
    final files = <File>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (controller?.shouldStop() ?? false) break;
      if (entity is File) {
        final ext = p.extension(entity.path).toLowerCase();
        if (_imageExts.contains(ext) || _videoExts.contains(ext)) {
          files.add(entity);
        }
      }
    }

    if (files.isEmpty) {
      controller?.complete();
      return;
    }

    final imageCount = files.where((f) =>
        _imageExts.contains(p.extension(f.path).toLowerCase())).length;
    final videoCount = files.length - imageCount;
    debugPrint('📁 找到 ${files.length} 个媒体文件'
        '（图片 $imageCount，视频 $videoCount）');

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

      // Phase 1: 批量计算 MD5 + EXIF（Isolate 中避免阻塞 UI）
      List<_FileMetaResult> metaResults;
      try {
        // processFileBatch 在 Isolate 中执行：
        // - Windows: 内部调 Rust rayon（后台线程池，不阻塞 Flutter 事件循环）
        // - 其他平台: 走 stub 的 Dart 顺序计算（也在 Isolate 中）
        metaResults = await compute(_processBatchInIsolate,
            batch.map((f) => f.path).toList());
      } catch (_) {
        // Fallback: 如果 Rust FFI 或 bridge 失败，用原来的独立 Isolate 方案
        final metaFutures =
            batch.map((file) => compute(_computeFileMeta, file.path)).toList();
        metaResults = await Future.wait(metaFutures);
      }

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

    // Phase B: 视频封面后处理（图片扫完后，统一处理文件夹下缺封面的视频）
    if (!(controller?.shouldStop() ?? false)) {
      yield ScanProgress(
        current: files.length,
        total: files.length,
        currentFile: '图片扫描完毕，正在处理视频封面...',
        added: added,
        duplicates: duplicates,
        updated: updated,
        phase: ScanPhase.generatingVideoCovers,
      );
      await _processVideosForFolder(folderPath, controller);
    }

    // 重建时间轴索引表
    if (!(controller?.shouldStop() ?? false)) {
      yield ScanProgress(
        current: files.length,
        total: files.length,
        currentFile: '正在更新时间轴索引...',
        added: added,
        duplicates: duplicates,
        updated: updated,
        phase: ScanPhase.rebuildingIndex,
      );
      try {
        await _db.rebuildDateIndexes();
        debugPrint('📅 时间轴索引表已重建');
      } catch (e) {
        debugPrint('❌ 重建时间轴索引失败: $e');
      }
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
    final item = await _indexFile(f);
    // 增量更新时间轴索引表
    try {
      await _db.addMediaToDateIndex(item);
    } catch (e) {
      debugPrint('⚠️ 更新时间轴索引失败（非致命）: $e');
    }
    // 单文件视频：不走完整文件夹扫描流程，直接补 Phase B 封面
    if (item.fileType == 'video') {
      debugPrint('🎬 单文件导入视频，准备提取封面: ${item.fileName}');
      try {
        await _processVideosForFolder(p.dirname(filePath), null);
      } catch (e) {
        debugPrint('🎬 单文件视频封面处理失败: $e');
      }
    }
    return item;
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
    final isVideo = _videoExts.contains(ext);
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
            fileType: Value(isVideo ? 'video' : 'image'),
            mimeType: Value(_mimeType(ext)),
            fileSizeBytes: Value(stat.size),
            fileModifiedAt: Value(stat.modified),
            indexedAt: Value(DateTime.now()),
            md5: Value(md5hash),
            isDeleted: const Value(false),
            isMissing: const Value(false),
          ));

      // 重新激活该媒体的标签关联（软删恢复时用到）
      await _db.reactivateMediaTags(existing.id);

      if (controller?.shouldStop() ?? false) {
        throw StateError('扫描已停止');
      }

      // 图片：保存 EXIF + 生成缩略图；视频：跳过（Phase B 处理）
      if (isImage) {
        await _extractAndSaveExif(file, existing.id,
            overwrite: forceReindexExif);
      }
      if (isImage && existing.thumbnailPath == null) {
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
    if (isImage) {
      try {
        if (controller?.shouldStop() ?? false) {
          throw StateError('扫描已停止');
        }
        thumbPath = await generateThumbnail(
            file, md5hash.isNotEmpty ? md5hash : path.hashCode.toString());
      } catch (e) {
        debugPrint('thumbnail error: $path - $e');
      }
    }

    if (controller?.shouldStop() ?? false) {
      throw StateError('扫描已停止');
    }

    await _db.upsertMediaItem(MediaItemsCompanion.insert(
      filePath: path,
      fileName: p.basename(path),
      fileType: isVideo ? 'video' : 'image',
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
    final isVideo = _videoExts.contains(ext);
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
            fileType: Value(isVideo ? 'video' : 'image'),
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

      // 图片：保存 EXIF；视频：跳过（Phase B 处理）
      if (isImage && meta.exifAttrs != null && meta.exifAttrs!.isNotEmpty) {
        await _saveExifAttrs(meta.exifAttrs!, existing.id,
            overwrite: forceReindexExif);
      }

      // 图片：生成缩略图；视频：跳过（Phase B 统一生成封面）
      if (isImage && existing.thumbnailPath == null) {
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
    if (isImage) {
      try {
        if (controller?.shouldStop() ?? false) {
          throw StateError('扫描已停止');
        }
        thumbPath = await _thumbWithSemaphore(
            file, md5hash.isNotEmpty ? md5hash : path.hashCode.toString());
      } catch (e) {
        debugPrint('thumbnail error: $path - $e');
      }
    }
    // 视频：缩略图留到 Phase B 统一处理

    if (controller?.shouldStop() ?? false) {
      throw StateError('扫描已停止');
    }

    await _db.upsertMediaItem(MediaItemsCompanion.insert(
      filePath: path,
      fileName: p.basename(path),
      fileType: isVideo ? 'video' : 'image',
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
      // 图片：保存 EXIF；视频：跳过
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
        imageWidth: Value(_parseIntAttr(attrs, 'PixelXDimension') ??
            _parseIntAttr(attrs, 'ExifImageWidth')),
        imageHeight: Value(_parseIntAttr(attrs, 'PixelYDimension') ??
            _parseIntAttr(attrs, 'ExifImageLength')),
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

      // ─── Rust FFI 快速通道（仅 Windows）───
      try {
        final result = await makeThumbnail(
          path: file.path,
          maxW: maxWidth,
          maxH: maxHeight,
          quality: quality,
        );
        if (result != null) {
          await File(thumbPath).writeAsBytes(result.jpegBytes);
          return thumbPath;
        }
      } catch (_) {
        // Rust FFI 不可用（非 Windows 或 DLL 加载失败），走 Dart 兜底
      }

      // ─── Dart 兜底：Isolate 解码 + package:image 缩放/编码 ───
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
  /// [onProgress] 可选，报告当前进度 (current, total, fileName)
  Future<int> generateMissingThumbnails({void Function(int current, int total, String fileName)? onProgress}) async {
    final query = _db.select(_db.mediaItems)
      ..where((t) => t.isDeleted.equals(false))
      ..where((t) => t.isMissing.equals(false));
    final items = await query.get();

    int count = 0;
    int index = 0;
    for (final item in items) {
      index++;
      onProgress?.call(index, items.length, item.fileName);
      // 让出足够时间给 Flutter 渲染管线完成一帧
      if (index % 20 == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }

      bool needGenerate = false;
      if (item.thumbnailPath == null) {
        needGenerate = true;
      } else {
        final thumbFile = File(item.thumbnailPath!);
        needGenerate = !await thumbFile.exists();
      }
      // 视频：已有封面但缺少视频元数据时，也需要补录
      if (item.fileType == 'video' && !needGenerate) {
        final vm = await _db.getVideoMeta(item.id);
        if (vm == null) needGenerate = true;
      }

      if (!needGenerate) continue;

      final file = File(item.filePath);
      if (!await file.exists()) continue;

      String? thumbPath;
      if (item.fileType == 'video') {
        // 视频使用 ffmpeg 提取封面 + 元数据
        try {
          thumbPath = await _extractVideoCover(item).timeout(const Duration(seconds: 30));
        } catch (e) {
          debugPrint('🎬 全库补视频信息失败: ${item.fileName} - $e');
        }
      } else {
        // 图片用原有缩略图生成器
        final mediaId = (item.md5?.isNotEmpty ?? false) ? item.md5! : item.id.toString();
        thumbPath = await generateThumbnail(file, mediaId);
      }
      if (thumbPath != null) {
        await _db.updateMedia(
            item.id, MediaItemsCompanion(thumbnailPath: Value(thumbPath)));
        count++;
      }
    }
    return count;
  }

  // ─────────────────────────────────────────────
  // 区域分析
  // ─────────────────────────────────────────────

  /// 全库重新分析区域
  Future<int> reAnalyzeAllRegions({void Function(int current, int total)? onProgress}) async {
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
    }, onProgress: onProgress);
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

  int? _parseIntAttr(Map<String, String> attrs, String key) {
    final v = attrs[key];
    if (v == null || v.isEmpty) return null;
    return int.tryParse(v);
  }

  String _mimeType(String ext) {
    const map = {
      '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
      '.png': 'image/png', '.webp': 'image/webp',
      '.gif': 'image/gif', '.bmp': 'image/bmp',
      '.heic': 'image/heic',
      '.mp4': 'video/mp4', '.mov': 'video/quicktime',
      '.avi': 'video/x-msvideo', '.mkv': 'video/x-matroska',
      '.wmv': 'video/x-ms-wmv', '.webm': 'video/webm',
      '.m4v': 'video/x-m4v', '.flv': 'video/x-flv',
      '.mts': 'video/mp2t',
      '.3gp': 'video/3gpp',
    };
    return map[ext] ?? 'application/octet-stream';
  }

  bool _shouldAbort(ScanController? controller) {
    return controller?.shouldStop() ?? false;
  }

  /// Phase B: 扫描后处理文件夹下的视频封面
  Future<void> _processVideosForFolder(
      String folderPath, ScanController? controller) async {
    debugPrint('🎬 ===== _processVideosForFolder START: $folderPath =====');
    final videos = await _db.getVideosNeedingCover(folderPath);
    debugPrint('🎬 需要封面的视频数量: ${videos.length}');
    if (videos.isEmpty) {
      debugPrint('🎬 ===== 无视频需处理，END =====');
      return;
    }

    // 检查 ffmpeg 是否可用
    final ffmpegPath = _findFfmpeg();
    final ffprobePath = _findFfprobe();
    debugPrint('🎬 ffmpeg 解析路径: $ffmpegPath');
    debugPrint('🎬 ffprobe 解析路径: $ffprobePath');
    final bool hasFfmpeg = File(ffmpegPath).existsSync() || ffmpegPath == 'ffmpeg';
    final bool hasFfprobe = File(ffprobePath).existsSync() || ffprobePath == 'ffprobe';
    if (!hasFfmpeg || !hasFfprobe) {
      debugPrint('⚠️ 未找到 ffmpeg / ffprobe，视频封面和元数据将跳过。');
      debugPrint('   ffmpeg 路径: $ffmpegPath (${hasFfmpeg ? "可用" : "不可用"})');
      debugPrint('   ffprobe 路径: $ffprobePath (${hasFfprobe ? "可用" : "不可用"})');
      debugPrint('   已将 ffmpeg 放到项目根目录 ffmpeg\\bin\\ 下？');
      debugPrint('   运行: .\\download_ffmpeg_dev.ps1');
      return;
    }

    debugPrint('🎬 开始处理 ${videos.length} 个视频封面...');

    for (var i = 0; i < videos.length; i++) {
      if (_shouldAbort(controller)) break;
      await controller?.checkPause();
      if (_shouldAbort(controller)) break;

      final video = videos[i];

      try {
        final coverPath =
            await _extractVideoCover(video).timeout(const Duration(seconds: 30));
        if (coverPath != null) {
          await _db.updateMedia(video.id,
              MediaItemsCompanion(thumbnailPath: Value(coverPath)));
        } else {
          debugPrint('🎬 跳过（无封面）: ${video.fileName}');
        }
      } catch (e) {
        debugPrint('🎬 视频处理失败: ${video.fileName} - $e');
      }
    }

    debugPrint('🎬 视频封面处理完成');
    debugPrint('🎬 ===== _processVideosForFolder END =====');
  }

  /// 提取视频首帧封面 + 元数据（当前: Dart ffmpeg CLI，V4 替换为 Rust）
  Future<String?> _extractVideoCover(MediaItem video) async {
    // TODO: V4 替换为 Rust process_video_files
    try {
      final thumbPath = PathHelper.instance.generateThumbnailPath(
          video.id.toString(), '.jpg');
      final ffmpegExe = _findFfmpeg();

      // 1. 提取封面帧
      final result = await Process.run(ffmpegExe, [
        '-y',
        '-i', video.filePath,
        '-vframes', '1',
        '-q:v', '3',
        '-vf', 'scale=300:-1',
        thumbPath,
      ]);

      if (result.exitCode != 0 || !File(thumbPath).existsSync()) {
        debugPrint('🎬 ffmpeg 封面提取失败: ${result.stderr}');
        return null;
      }

      // 2. 提取元数据（ffprobe）
      await _extractVideoMeta(video);

      return thumbPath;
    } catch (e) {
      debugPrint('🎬 ffmpeg not available: $e');
      return null;
    }
  }

  /// 使用 ffprobe 提取视频元数据并写入 VideoMetas 表
  Future<void> _extractVideoMeta(MediaItem video) async {
    try {
      final ffprobeExe = _findFfprobe();
      debugPrint('🎬 ffprobe 开始: ${video.fileName}');
      final result = await Process.run(ffprobeExe, [
        '-v', 'error',
        '-select_streams', 'v:0',
        '-show_entries',
        'stream=codec_name,width,height,bit_rate',
        '-of', 'csv=p=0',
        video.filePath,
      ]);

      debugPrint('🎬 ffprobe stdout: ${result.stdout}');
      debugPrint('🎬 ffprobe stderr: ${result.stderr}');
      debugPrint('🎬 ffprobe exit: ${result.exitCode}');

      if (result.exitCode != 0) {
        debugPrint('🎬 ffprobe 退出码非 0，跳过元数据');
        return;
      }

      // ffprobe csv 固定顺序: codec_name, width, height, bit_rate
      final fields = (result.stdout as String).trim().split(',');
      debugPrint('🎬 ffprobe 字段: $fields');
      if (fields.length < 3) {
        debugPrint('🎬 ffprobe 字段不足，跳过元数据');
        return;
      }

      final codec = fields[0].trim();
      final width = int.tryParse(fields[1].trim()) ?? 0;
      final height = int.tryParse(fields[2].trim()) ?? 0;
      final bitrate = (fields.length >= 4)
          ? (int.tryParse(fields[3].trim()) ?? 0)
          : 0;
      debugPrint('🎬 解析: width=$width height=$height codec=$codec bitrate=$bitrate');

      // duration 单独查询（更可靠）
      double duration = 0;
      try {
        final durResult = await Process.run(ffprobeExe, [
          '-v', 'error',
          '-show_entries', 'format=duration',
          '-of', 'csv=p=0',
          video.filePath,
        ]);
        if (durResult.exitCode == 0) {
          duration = double.tryParse((durResult.stdout as String).trim()) ?? 0;
        }
      } catch (_) {}
      debugPrint('🎬 duration=$duration');

      if (width > 0 && height > 0) {
        await _db.upsertVideoMeta(video.id,
            durationSec: duration,
            width: width,
            height: height,
            codec: codec,
            bitrate: bitrate);
        debugPrint('🎬 已写入 VideoMetas: id=${video.id}');
      } else {
        debugPrint('🎬 分辨率无效，未写入 VideoMetas');
      }
    } catch (e) {
      debugPrint('🎬 ffprobe 元数据提取异常: $e');
    }
  }

  /// 查找 ffmpeg：exe 同目录 → 向上逐层查找 → 系统 PATH
  String _findFfmpeg() {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    debugPrint('🔍 查找 ffmpeg... exe目录: $exeDir');
    // 1. exe 同目录下的便携版（发布包）
    final bundled = p.join(exeDir, 'ffmpeg', 'bin', 'ffmpeg.exe');
    if (File(bundled).existsSync()) {
      debugPrint('🔍 找到 (同目录): $bundled');
      return bundled;
    }
    // 2. 向上逐层查找（开发调试：项目根目录 ffmpeg/）
    var dir = exeDir;
    for (var i = 0; i < 8; i++) {
      final dev = p.join(dir, 'ffmpeg', 'bin', 'ffmpeg.exe');
      if (File(dev).existsSync()) {
        debugPrint('🔍 找到 (向上 $i 层): $dev');
        return dev;
      }
      final parent = p.dirname(dir);
      if (parent == dir) break;
      dir = parent;
    }
    // 3. 系统 PATH
    debugPrint('🔍 未在目录树中找到，回退系统 PATH');
    return 'ffmpeg';
  }

  /// 查找 ffprobe：同上
  String _findFfprobe() {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final bundled = p.join(exeDir, 'ffmpeg', 'bin', 'ffprobe.exe');
    if (File(bundled).existsSync()) return bundled;
    var dir = exeDir;
    for (var i = 0; i < 8; i++) {
      final dev = p.join(dir, 'ffmpeg', 'bin', 'ffprobe.exe');
      if (File(dev).existsSync()) return dev;
      final parent = p.dirname(dir);
      if (parent == dir) break;
      dir = parent;
    }
    return 'ffprobe';
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
  print('[PicGuide] $msg');
}
