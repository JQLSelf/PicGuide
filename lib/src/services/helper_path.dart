// ============================================================
// lib/src/services/helper_path.dart
// 路径工具类：管理数据库和缓存目录
// ============================================================
import 'dart:io';
import 'package:path/path.dart' as p;

/// 路径管理工具：统一管理数据库、缩略图缓存等路径
class PathHelper {
  PathHelper._();

  static PathHelper? _instance;
  static PathHelper get instance => _instance ??= PathHelper._();

  /// 应用根目录（可执行文件所在目录的父目录）
  late Directory _appRootDir;

  /// 数据目录（存放数据库）
  late Directory _dataDir;

  /// 缩略图缓存目录
  late Directory _thumbnailDir;

  /// 初始化路径（必须在使用前调用）
  Future<void> initialize() async {
    // 获取可执行文件路径
    final exePath = Platform.resolvedExecutable;
    final exeDir = p.dirname(exePath);

    // 应用根目录：通常是 exe 所在目录
    // 如果是开发环境（build\windows\runner\Debug），则向上找两级到项目根目录
    _appRootDir = Directory(exeDir);

    // 数据目录：应用根目录下的 data 文件夹
    _dataDir = Directory(p.join(_appRootDir.path, 'data'));
    if (!await _dataDir.exists()) {
      await _dataDir.create(recursive: true);
    }

    // 缩略图缓存目录：data/thumbnails
    _thumbnailDir = Directory(p.join(_dataDir.path, 'thumbnails'));
    if (!await _thumbnailDir.exists()) {
      await _thumbnailDir.create(recursive: true);
    }
  }

  /// 数据库文件路径
  String get databasePath => p.join(_dataDir.path, 'pixelvault.db');

  /// 缩略图缓存目录
  Directory get thumbnailDir => _thumbnailDir;

  /// 生成缩略图文件路径（基于文件 MD5 或 ID）
  String generateThumbnailPath(String mediaId, String extension) {
    // 按首字符分目录，避免单目录文件过多
    final firstChar = mediaId.isNotEmpty ? mediaId[0].toLowerCase() : '0';
    final subDir = Directory(p.join(_thumbnailDir.path, firstChar));
    if (!subDir.existsSync()) {
      subDir.createSync(recursive: true);
    }
    return p.join(subDir.path, '${mediaId}_thumb$extension');
  }

  /// 检查缩略图是否已存在
  bool thumbnailExists(String mediaId, String extension) {
    final path = generateThumbnailPath(mediaId, extension);
    return File(path).existsSync();
  }

  /// 清理过期的缩略图（可选）
  Future<void> cleanupOldThumbnails(Set<String> validMediaIds) async {
    if (!await _thumbnailDir.exists()) return;

    await for (final entity in _thumbnailDir.list(recursive: true)) {
      if (entity is File) {
        final fileName = p.basename(entity.path);
        final mediaId = fileName.split('_thumb').first;
        if (!validMediaIds.contains(mediaId)) {
          await entity.delete();
        }
      }
    }
  }
}
