// ============================================================
// lib/src/db/database.dart
// drift 跨平台 SQLite 数据库定义
// 生成命令: dart run build_runner build --delete-conflicting-outputs
// schemaVersion: 4
//   v1 -> v2: 增 md5 / isMissing
//   v2 -> v3: 增 exifDatas.province / district（离线反查省市县）
//   v3 -> v4: 增 mediaDateIndexes 时间轴索引表
// ============================================================
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import '../services/helper_path.dart';

part 'database.g.dart';

// ─────────────────────────────────────────────
// 表定义
// ─────────────────────────────────────────────

/// 媒体文件归档表
@DataClassName('MediaItem')
class MediaItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get filePath => text().unique()();
  TextColumn get fileName => text()();
  TextColumn get fileType => text()(); // 'image' | 'video'
  TextColumn get mimeType => text().nullable()();
  IntColumn get fileSizeBytes => integer().nullable()();
  DateTimeColumn get fileModifiedAt => dateTime().nullable()();
  DateTimeColumn get indexedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get thumbnailPath => text().nullable()();

  /// MD5 哈希，用于去重与内容一致性校验
  TextColumn get md5 => text().nullable()();

  /// 文件是否已从归档中移除（软删除）
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  /// 文件是否在磁盘上缺失（对账发现）
  BoolColumn get isMissing => boolean().withDefault(const Constant(false))();
}

/// EXIF 信息表（一对一 mediaItem）
@DataClassName('ExifData')
class ExifDatas extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get mediaItemId =>
      integer().references(MediaItems, #id, onDelete: KeyAction.cascade)();
  TextColumn get make => text().nullable()();
  TextColumn get model => text().nullable()();
  TextColumn get software => text().nullable()();
  DateTimeColumn get dateTaken => dateTime().nullable()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get cityName => text().nullable()();

  /// 省 / 自治区 / 直辖市（离线 RegionResolver 写入）
  TextColumn get province => text().nullable()();

  /// 县 / 区（当前数据源未含，留作扩展）
  TextColumn get district => text().nullable()();
  TextColumn get isoSpeed => text().nullable()();
  TextColumn get fNumber => text().nullable()();
  TextColumn get exposureTime => text().nullable()();
  TextColumn get focalLength => text().nullable()();
  IntColumn get imageWidth => integer().nullable()();
  IntColumn get imageHeight => integer().nullable()();
  TextColumn get orientation => text().nullable()();
  TextColumn get rawJson => text().nullable()();
}

/// 标签定义表
@DataClassName('Tag')
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get color => text().withDefault(const Constant('#4A90D9'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// 兼容旧代码：把 color 列暴露为 colorHex 访问器（仅取可空 String?）
extension TagColorHex on Tag {
  String? get colorHex => color;
}

/// 媒体-标签关联表（多对多）
/// active：用于软删除时标记为 false，不参与统计；MD5 匹配重新导入时恢复为 true
@DataClassName('MediaTag')
class MediaTags extends Table {
  IntColumn get mediaItemId =>
      integer().references(MediaItems, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagId =>
      integer().references(Tags, #id, onDelete: KeyAction.cascade)();
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {mediaItemId, tagId};
}

/// 文件夹扫描记录
@DataClassName('FolderScan')
class FolderScans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get folderPath => text().unique()();
  DateTimeColumn get lastScannedAt =>
      dateTime().withDefault(currentDateAndTime)();
  IntColumn get itemCount => integer().withDefault(const Constant(0))();
  IntColumn get missingCount => integer().withDefault(const Constant(0))();
}

/// 时间轴日期索引表（加速时间轴侧边栏跳转）
/// 每条记录表示一个日期（如 2024-01-15）有多少张照片，以及它们在全库排序中的起始偏移量
@DataClassName('MediaDateIndex')
class MediaDateIndexes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get dateKey => text().unique()(); // 'YYYY-MM-DD'
  IntColumn get count => integer().withDefault(const Constant(0))();
  IntColumn get firstOffset =>
      integer().withDefault(const Constant(0))(); // 起始偏移量（废弃，改用实时计算）
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

/// 月份桶（用于时间轴侧边栏，YYYY-MM 粒度）
class MonthlyBucket {
  final String dateKey; // 'YYYY-MM'
  final int count;
  final int firstOffset; // 该月首项在排序后的全库列表中的偏移量
  const MonthlyBucket({
    required this.dateKey,
    required this.count,
    required this.firstOffset,
  });
}

// ─────────────────────────────────────────────
// 数据库类
// ─────────────────────────────────────────────

@DriftDatabase(tables: [MediaItems, ExifDatas, Tags, MediaTags, FolderScans, MediaDateIndexes])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // v1 -> v2: 增 md5 / isMissing 两列
          if (from < 2) {
            await m.addColumn(mediaItems, mediaItems.md5);
            await m.addColumn(mediaItems, mediaItems.isMissing);
            await m.addColumn(folderScans, folderScans.missingCount);
          }
          // v2 -> v3: 增 exifDatas.province / district
          if (from < 3) {
            await m.addColumn(exifDatas, exifDatas.province);
            await m.addColumn(exifDatas, exifDatas.district);
          }
          // v3 -> v4: 增 mediaDateIndexes 时间轴索引表
          if (from < 4) {
            await m.createTable(mediaDateIndexes);
          }
          // v4 -> v5: 增 mediaTags.active 列
          if (from < 5) {
            await m.addColumn(mediaTags, mediaTags.active);
          }
        },
      );

  // ── 媒体查询 ──

  /// 全库获取所有未删除媒体（默认浏览器视图）
  Future<List<MediaItemWithMeta>> getAllMedia({
    bool includeMissing = false,
  }) async {
    final query = select(mediaItems)..where((t) => t.isDeleted.equals(false));
    if (!includeMissing) {
      query.where((t) => t.isMissing.equals(false));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.indexedAt)]);
    final items = await query.get();
    return enrichItems(items);
  }

  /// 按"模拟文件夹"获取（按 filePath 前缀）
  ///
  /// 注意：不要用 _escapeLike + escapeChar 转义 `_`。
  /// 真实数据测试显示：把 `%` 之外的字符 escape 后再加 `ESCAPE '\'`，
  /// SQLite 会把外层的 `\%` 解释成"字面 %"，**整个查询永远 0 行**。
  /// SQLite 的 `_` 通配符对字面 `_` 是匹配的（通配符 = "任意单字符"包含字面下划线），
  /// 所以保留原始 LIKE `prefix%` 反而是对的。
  Future<List<MediaItemWithMeta>> getMediaInFolder(String folder) async {
    final normFolder = folder.replaceAll('/', '\\');
    final sep = '\\';
    final prefix = normFolder.isEmpty ? '' : '$normFolder$sep';
    final prefixFwd = prefix.replaceAll('\\', '/');
    final items = await (select(mediaItems)
          ..where((t) =>
              t.filePath.like('$prefix%') |
              t.filePath.like('$prefixFwd%'))
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.indexedAt)]))
        .get();
    return enrichItems(items);
  }

  /// 列出已归档的所有文件夹（扁平列表，保留兼容）
  Future<List<FolderBucket>> getAllFolders() async {
    final rows = await (select(mediaItems)
          ..where((t) => t.isDeleted.equals(false)))
        .get();
    final map = <String, int>{};
    for (final r in rows) {
      final folder = p.dirname(r.filePath);
      map[folder] = (map[folder] ?? 0) + 1;
    }
    return map.entries
        .map((e) => FolderBucket(folder: e.key, count: e.value))
        .toList()
      ..sort((a, b) => a.folder.compareTo(b.folder));
  }

  /// 构建完整的文件夹树（从所有已归档文件的目录路径构建）
  Future<FolderTreeNode> buildFolderTree() async {
    final rows = await (select(mediaItems)
          ..where((t) => t.isDeleted.equals(false)))
        .get();
    // 收集每个路径的文件数
    final pathCounts = <String, int>{};
    final allDirs = <String>{};
    for (final r in rows) {
      final dir = p.dirname(r.filePath);
      if (dir.isEmpty) continue; // 跳过空路径
      pathCounts[dir] = (pathCounts[dir] ?? 0) + 1;
      // 收集所有祖先路径
      var current = p.dirname(dir);
      var safety = 0;
      while (current != dir &&
          current.isNotEmpty &&
          current != '.' &&
          safety < 64) {
        allDirs.add(current);
        final parent = p.dirname(current);
        if (parent == current) break;
        current = parent;
        safety++;
      }
      allDirs.add(dir);
    }
    // 找根节点：最短公共前缀或系统盘符
    String? rootPath;
    final sortedDirs = allDirs.toList()
      ..sort((a, b) => a.length.compareTo(b.length));
    if (sortedDirs.isEmpty) {
      return FolderTreeNode(path: '', name: 'root', fileCount: 0);
    }
    // 找到没有其他目录作为其父的顶级目录
    final topLevels = <String>{};
    for (final d in sortedDirs) {
      final parent = p.dirname(d);
      if (!allDirs.contains(parent) || parent == d) {
        topLevels.add(d);
      }
    }
    // 如果有多个顶级，用虚拟根包裹
    if (topLevels.length == 1) {
      rootPath = topLevels.first;
    } else {
      // 多个顶层 → 虚拟根
      rootPath = '';
    }

    return _buildNode(rootPath ?? '', pathCounts, allDirs, sortedDirs);
  }

  FolderTreeNode _buildNode(
    String nodePath,
    Map<String, int> pathCounts,
    Set<String> allDirs,
    List<String> sortedDirs,
  ) {
    final name = nodePath.isEmpty ? '全部文件夹' : p.basename(nodePath);
    final directCount = pathCounts[nodePath] ?? 0;
    // 找直接子目录
    final children = <FolderTreeNode>[];
    for (final d in sortedDirs) {
      // 防止把节点自身作为子节点（修复：根目录 p.dirname(root)==root 时会无限递归）
      if (d == nodePath) continue;
      final parent = p.dirname(d);
      if (parent == nodePath ||
          (nodePath.isEmpty && !allDirs.contains(parent))) {
        children.add(_buildNode(d, pathCounts, allDirs, sortedDirs));
      }
    }
    children.sort((a, b) => a.name.compareTo(b.name));
    return FolderTreeNode(
      path: nodePath,
      name: name,
      fileCount: directCount,
      children: children,
    );
  }

  /// 获取指定文件夹前缀下的所有媒体记录（递归，仅 MediaItem 不含 EXIF）
  /// 用于扫描前批量预加载，避免逐条 DB 查询
  ///
  /// 注意：不要用 _escapeLike + escapeChar。详见 getMediaInFolder 注释。
  Future<List<MediaItem>> getItemsByFolderPrefix(String folderPath) async {
    final normFolder = folderPath.replaceAll('/', '\\');
    final sep = '\\';
    final prefix = normFolder.isEmpty ? '' : '$normFolder$sep';
    final prefixFwd = prefix.replaceAll('\\', '/');
    return (select(mediaItems)
          ..where((t) =>
              t.filePath.like('$prefix%') |
              t.filePath.like('$prefixFwd%'))
          ..where((t) => t.isDeleted.equals(false)))
        .get();
  }

  /// 获取指定文件夹下直接包含的媒体（不递归子目录）
  ///
  /// 注意：不要用 _escapeLike + escapeChar。详见 getMediaInFolder 注释。
  Future<List<MediaItemWithMeta>> getDirectMediaInFolder(String folder) async {
    // 统一使用反斜杠处理 Windows 路径，避免分隔符不匹配导致 LIKE 查询失败
    final normFolder = folder.replaceAll('/', '\\');
    final sep = '\\';
    final prefix = normFolder.isEmpty ? '' : '$normFolder$sep';
    // 同时匹配正斜杠和反斜杠路径
    final prefixFwd = prefix.replaceAll('\\', '/');
    final items = await (select(mediaItems)
          ..where((t) =>
              t.filePath.like('$prefix%') |
              t.filePath.like('$prefixFwd%'))
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.indexedAt)]))
        .get();
    // 过滤出直接在当前目录下的文件（不含子目录）。
    // 必须按 item.filePath 实际使用的分隔符选对应前缀来截 substring，
    // 否则 prefix（反斜杠）和 filePath（可能是正斜杠）长度对不上，
    // 深嵌套路径下会整条 relative 错位 → 误判为子目录 → 文件被全部过滤掉。
    final direct = items.where((item) {
      if (normFolder.isEmpty) return true;
      final actualPrefix =
          item.filePath.contains('/') ? prefixFwd : prefix;
      if (!item.filePath.startsWith(actualPrefix)) return false;
      final relative = item.filePath.substring(actualPrefix.length);
      return !relative.contains('\\') && !relative.contains('/');
    }).toList();
    return enrichItems(direct);
  }

  /// 获取指定文件夹的直接子目录及其文件计数
  /// 注意：即使直系子目录本身没有文件，只要其子树内有文件，也会包含在内
  Future<List<SubFolderEntry>> getSubFolders(String parentPath) async {
    final normParent = parentPath.replaceAll('/', '\\');
    final prefix = normParent.isEmpty
        ? ''
        : (normParent.endsWith('\\') ? normParent : '$normParent\\');
    final rows = await (select(mediaItems)
          ..where((t) => t.isDeleted.equals(false)))
        .get();
    final subMap = <String, int>{};
    for (final r in rows) {
      // 统一使用反斜杠处理路径
      final normPath = r.filePath.replaceAll('/', '\\');
      final dir = p.dirname(normPath);

      // 跳过当前目录自身或无关联路径
      if (dir == normParent || !dir.startsWith(prefix)) continue;

      // 提取 normParent 的直系子目录
      // 例如 D:\XiaomiThemeEdit\deep\img.jpg → 直系子目录为 XiaomiThemeEdit
      final relative = dir.substring(prefix.length);
      final firstSep = relative.indexOf('\\');
      final childName =
          firstSep == -1 ? relative : relative.substring(0, firstSep);
      final childPath = normParent.isEmpty
          ? childName
          : (normParent.endsWith('\\')
              ? '$normParent$childName'
              : '$normParent\\$childName');

      subMap[childPath] = (subMap[childPath] ?? 0) + 1;
    }
    return subMap.entries
        .map((e) => SubFolderEntry(
            path: e.key, name: p.basename(e.key), fileCount: e.value))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  // _escapeLike 不再使用——escape 后再加 ESCAPE '\\' 子句会让外层 %
  // 被解释为字面 %，整个查询永远 0 行。保留函数以避免外部依赖方编译错误。
  // 如需 LIKE 模糊匹配，直接用 .like('$prefix%') 即可。
  // ignore: unused_element
  static String _escapeLike(String s) =>
      s.replaceAll('%', '\\%').replaceAll('_', '\\_');

  /// 批量富化：一次性查询所有 EXIF 和 Tags，消除 N+1
  /// 保持与 items 相同的顺序
  Future<List<MediaItemWithMeta>> enrichItems(List<MediaItem> items) async {
    if (items.isEmpty) return [];
    final ids = items.map((i) => i.id).toList();

    // 批量加载 EXIF
    final exifRows = await (select(exifDatas)
          ..where((e) => e.mediaItemId.isIn(ids)))
        .get();
    final exifMap = {for (final e in exifRows) e.mediaItemId: e};

    // 批量加载媒体-标签关联（仅活跃的关联）
    final mtRows = await (select(mediaTags)
          ..where((mt) => mt.mediaItemId.isIn(ids))
          ..where((mt) => mt.active.equals(true)))
        .get();
    final tagIdSet = mtRows.map((r) => r.tagId).toSet();

    // 批量加载标签
    final allTags = tagIdSet.isEmpty
        ? <Tag>[]
        : await (select(tags)..where((t) => t.id.isIn(tagIdSet))).get();
    final tagMap = {for (final t in allTags) t.id: t};

    // 按 mediaItemId 分组 tag
    final mediaTagMap = <int, List<Tag>>{};
    for (final mt in mtRows) {
      mediaTagMap.putIfAbsent(mt.mediaItemId, () => []);
      final tag = tagMap[mt.tagId];
      if (tag != null) {
        mediaTagMap[mt.mediaItemId]!.add(tag);
      }
    }

    // 保持原始顺序返回
    return items.map((item) => MediaItemWithMeta(
          item: item,
          exif: exifMap[item.id],
          tags: mediaTagMap[item.id] ?? [],
        )).toList();
  }

  /// 按标签筛选（仅活跃关联）
  Future<List<MediaItem>> getItemsByTag(int tagId) async {
    final taggedIds = await (select(mediaTags)
          ..where((mt) => mt.tagId.equals(tagId))
          ..where((mt) => mt.active.equals(true)))
        .get()
        .then((rows) => rows.map((r) => r.mediaItemId).toList());
    if (taggedIds.isEmpty) return [];
    return (select(mediaItems)
          ..where((t) => t.id.isIn(taggedIds))
          ..where((t) => t.isDeleted.equals(false))
          ..where((t) => t.isMissing.equals(false)))
        .get();
  }

  /// EXIF 筛选 - 按城市名模糊匹配
  Future<List<MediaItem>> getItemsByCity(String city) async {
    // LIKE 通配符：_ 和 % 仍按默认规则处理（即对 city 字符串做子串匹配）。
    // 如果 city 字符串里包含 _ 或 % 会触发非预期匹配——但城市名是用户数据，
    // 这种 corner case 不在此处防御（LIKE 本质是模糊匹配）。
    final exifRows = await (select(exifDatas)
          ..where((e) => e.cityName.like('%$city%')))
        .get();
    final ids = exifRows.map((e) => e.mediaItemId).toList();
    if (ids.isEmpty) return [];
    return (select(mediaItems)
          ..where((t) => t.id.isIn(ids))
          ..where((t) => t.isDeleted.equals(false)))
        .get();
  }

  /// EXIF 筛选 - 按日期范围
  Future<List<MediaItem>> getItemsByDateRange(
      DateTime from, DateTime to) async {
    final exifRows = await (select(exifDatas)
          ..where((e) => e.dateTaken.isBiggerOrEqualValue(from))
          ..where((e) => e.dateTaken.isSmallerOrEqualValue(to)))
        .get();
    final ids = exifRows.map((e) => e.mediaItemId).toList();
    if (ids.isEmpty) return [];
    return (select(mediaItems)
          ..where((t) => t.id.isIn(ids))
          ..where((t) => t.isDeleted.equals(false)))
        .get();
  }

  // ── MD5 去重 ──

  /// 用 MD5 查询已存在记录（null=未入库）
  Future<MediaItem?> findByMd5(String md5) async {
    if (md5.isEmpty) return null;
    return (select(mediaItems)..where((t) => t.md5.equals(md5)))
        .getSingleOrNull();
  }

  /// 用 filePath 查询
  Future<MediaItem?> findByPath(String path) =>
      (select(mediaItems)..where((t) => t.filePath.equals(path)))
          .getSingleOrNull();

  // ── 标签操作 ──

  Future<int> addTag(String name, {String color = '#4A90D9'}) =>
      into(tags).insert(TagsCompanion.insert(name: name, color: Value(color)));

  Future<void> addTagToMedia(int mediaId, int tagId) =>
      into(mediaTags).insertOnConflictUpdate(
        MediaTagsCompanion.insert(mediaItemId: mediaId, tagId: tagId),
      );

  Future<void> removeTagFromMedia(int mediaId, int tagId) => (delete(mediaTags)
        ..where((mt) => mt.mediaItemId.equals(mediaId))
        ..where((mt) => mt.tagId.equals(tagId)))
      .go();

  Future<void> addTagToManyMedia(List<int> mediaIds, int tagId) async {
    if (mediaIds.isEmpty) return;
    await batch((b) {
      for (final id in mediaIds) {
        b.insert(
            mediaTags, MediaTagsCompanion.insert(mediaItemId: id, tagId: tagId),
            mode: InsertMode.insertOrIgnore);
      }
    });
  }

  Future<void> removeTagFromManyMedia(List<int> mediaIds, int tagId) async {
    if (mediaIds.isEmpty) return;
    await (delete(mediaTags)
          ..where((mt) => mt.mediaItemId.isIn(mediaIds))
          ..where((mt) => mt.tagId.equals(tagId)))
        .go();
  }

  /// 重新激活某媒体的所有标签关联（软删恢复时用）
  Future<void> reactivateMediaTags(int mediaId) async {
    await (update(mediaTags)
          ..where((t) => t.mediaItemId.equals(mediaId)))
        .write(const MediaTagsCompanion(active: Value(true)));
  }

  Future<List<Tag>> getAllTags() => select(tags).get();

  // ── 归档操作 ──

  Future<void> upsertMediaItem(MediaItemsCompanion item) =>
      into(mediaItems).insertOnConflictUpdate(item);

  Future<void> updateMedia(int id, MediaItemsCompanion patch) =>
      (update(mediaItems)..where((t) => t.id.equals(id))).write(patch);

  Future<void> upsertExif(ExifDatasCompanion exif) =>
      into(exifDatas).insertOnConflictUpdate(exif);

  // ── 时间轴索引表操作 ──

  /// 根据媒体项的 EXIF/fileModifiedAt 计算日期 key (YYYY-MM-DD)
  String _dateKeyForItem(MediaItem item, {ExifData? exif}) {
    DateTime date;
    if (exif?.dateTaken != null) {
      date = exif!.dateTaken!;
    } else {
      date = item.fileModifiedAt ?? item.indexedAt ?? DateTime.now();
    }
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// 增量更新：新增一个媒体项到日期索引表
  Future<void> addMediaToDateIndex(MediaItem item, {ExifData? exif}) async {
    final dateKey = _dateKeyForItem(item, exif: exif);
    await upsertDateIndex(dateKey, delta: 1);
  }

  /// 增量更新：媒体项日期变化后，更新索引表
  ///（先减旧日期计数，再加新日期计数）
  Future<void> updateMediaDateIndex({
    required MediaItem item,
    ExifData? oldExif,
    ExifData? newExif,
  }) async {
    final oldKey = _dateKeyForItem(item, exif: oldExif);
    final newKey = _dateKeyForItem(item, exif: newExif);
    if (oldKey != newKey) {
      await upsertDateIndex(oldKey, delta: -1);
      await upsertDateIndex(newKey, delta: 1);
    }
  }

  /// 插入或更新日期索引（增量更新 count）
  Future<void> upsertDateIndex(String dateKey, {int delta = 1}) async {
    final existing = await (select(mediaDateIndexes)
          ..where((t) => t.dateKey.equals(dateKey)))
        .getSingleOrNull();
    if (existing == null) {
      await into(mediaDateIndexes).insert(MediaDateIndexesCompanion.insert(
            dateKey: dateKey,
            count: Value(delta),
            firstOffset: const Value(0), // 不再使用，实时计算
          ));
    } else {
      final newCount = existing.count + delta;
      if (newCount <= 0) {
        // 计数为 0 或负数，删除该日期索引
        await (delete(mediaDateIndexes)
              ..where((t) => t.dateKey.equals(dateKey)))
            .go();
      } else {
        await (update(mediaDateIndexes)..where((t) => t.dateKey.equals(dateKey)))
            .write(MediaDateIndexesCompanion(
          count: Value(newCount),
          updatedAt: Value(DateTime.now()),
        ));
      }
    }
  }

  /// 获取所有日期索引（按 dateKey 降序，用于时间轴侧边栏）
  Future<List<MediaDateIndex>> getDateIndexes() async {
    return (select(mediaDateIndexes)
          ..orderBy([(t) => OrderingTerm.desc(t.dateKey)]))
        .get();
  }

  /// 按月聚合日期索引（用于时间轴侧边栏的"YYYY-MM"桶展示）
  /// 从 MediaDateIndexes 表中读取每日数据，聚合为月度统计
  Future<List<MonthlyBucket>> getMonthlyDateBuckets() async {
    final dailyIndexes = await getDateIndexes();

    final monthMap = <String, int>{};
    for (final idx in dailyIndexes) {
      // dateKey = "YYYY-MM-DD" → "YYYY-MM"
      final monthKey = idx.dateKey.substring(0, 7);
      monthMap[monthKey] = (monthMap[monthKey] ?? 0) + idx.count;
    }

    // 按月降序排列
    final sortedMonths = monthMap.keys.toList()..sort((a, b) => b.compareTo(a));
    final result = <MonthlyBucket>[];
    int runningOffset = 0;
    for (final dateKey in sortedMonths) {
      result.add(MonthlyBucket(
        dateKey: dateKey,
        count: monthMap[dateKey]!,
        firstOffset: runningOffset,
      ));
      runningOffset += monthMap[dateKey]!;
    }
    return result;
  }

  /// 删除指定日期的索引
  Future<void> deleteDateIndex(String dateKey) async {
    await (delete(mediaDateIndexes)
          ..where((t) => t.dateKey.equals(dateKey)))
        .go();
  }

  /// 全量重建日期索引（用于全盘重扫）
  /// 返回重建后的日期索引列表
  Future<List<MediaDateIndex>> rebuildDateIndexes() async {
    // 1. 清空现有索引
    await (delete(mediaDateIndexes)).go();

    // 2. 查询所有未软删/未缺失的照片
    final rows = await (select(mediaItems)
          ..where((t) => t.isDeleted.equals(false))
          ..where((t) => t.isMissing.equals(false)))
        .get();
    if (rows.isEmpty) return [];

    // 3. 批量加载所有 EXIF 数据（避免 N+1）
    final ids = rows.map((r) => r.id).toList();
    final allExif = await (select(exifDatas)
          ..where((e) => e.mediaItemId.isIn(ids)))
        .get();
    final exifMap = {for (final e in allExif) e.mediaItemId: e};

    // 4. 按日期分组计数
    final dateCountMap = <String, int>{};
    for (final item in rows) {
      final exif = exifMap[item.id];
      DateTime dateTaken;
      if (exif?.dateTaken != null) {
        dateTaken = exif!.dateTaken!;
      } else {
        dateTaken = item.fileModifiedAt ?? item.indexedAt ?? DateTime.now();
      }
      final dateKey = _formatDateKey(dateTaken);
      dateCountMap[dateKey] = (dateCountMap[dateKey] ?? 0) + 1;
    }

    // 5. 批量插入新的索引（按日期降序）
    final sortedKeys = dateCountMap.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // 降序

    for (final dateKey in sortedKeys) {
      await into(mediaDateIndexes).insert(MediaDateIndexesCompanion.insert(
            dateKey: dateKey,
            count: Value(dateCountMap[dateKey]!),
            firstOffset: const Value(0), // 不再使用，实时计算
          ));
    }

    // 6. 返回重建后的索引
    return getDateIndexes();
  }

  /// 减少指定日期的计数（用于软删除）
  Future<void> decrementDateIndexCount(List<int> mediaIds) async {
    if (mediaIds.isEmpty) return;

    // 查询这些媒体的日期
    final items = await (select(mediaItems)
          ..where((t) => t.id.isIn(mediaIds)))
        .get();
    if (items.isEmpty) return;

    // 批量加载这些媒体的 EXIF 数据（避免 N+1）
    final allExif = await (select(exifDatas)
          ..where((e) => e.mediaItemId.isIn(mediaIds)))
        .get();
    final exifMap = {for (final e in allExif) e.mediaItemId: e};

    // 按日期分组，统计每个日期需要减少的计数
    final dateDeltaMap = <String, int>{};
    for (final item in items) {
      final exif = exifMap[item.id];
      DateTime dateTaken;
      if (exif?.dateTaken != null) {
        dateTaken = exif!.dateTaken!;
      } else {
        dateTaken = item.fileModifiedAt ?? item.indexedAt ?? DateTime.now();
      }
      final dateKey = _formatDateKey(dateTaken);
      dateDeltaMap[dateKey] = (dateDeltaMap[dateKey] ?? 0) + 1;
    }

    // 更新每个日期的计数
    for (final entry in dateDeltaMap.entries) {
      await upsertDateIndex(entry.key, delta: -entry.value);
    }
  }

  /// 获取某日期的起始偏移量（实时计算，不依赖 firstOffset）
  Future<int> getDateOffset(String dateKey) async {
    // 计算比 dateKey 更新的所有日期的 count 之和
    final rows = await (select(mediaDateIndexes)
          ..where((t) => t.dateKey.isBiggerThanValue(dateKey)))
        .get();
    return rows.fold<int>(0, (sum, r) => sum + r.count);
  }

  /// 格式化日期为 YYYY-MM-DD
  String _formatDateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// 软删除：把 isDeleted 置为 true
  /// 同时维护时间轴索引表，并将关联标签标记为不活跃
  Future<void> softDeleteMedia(List<int> ids) async {
    if (ids.isEmpty) return;

    // 1. 先减少时间轴索引表中对应日期的计数
    await decrementDateIndexCount(ids);

    // 2. 执行软删除
    await (update(mediaItems)..where((t) => t.id.isIn(ids)))
        .write(const MediaItemsCompanion(isDeleted: Value(true)));

    // 3. 将关联标签标记为不活跃（保留关联关系，仅不参与统计）
    await (update(mediaTags)..where((t) => t.mediaItemId.isIn(ids)))
        .write(const MediaTagsCompanion(active: Value(false)));
  }

  /// 标记文件夹下"在磁盘上已不存在"的记录
  Future<int> markMissingInFolder(String folder) async {
    final normFolder = folder.replaceAll('/', '\\');
    final sep = '\\';
    final prefix = normFolder.isEmpty ? '' : '$normFolder$sep';
    final prefixFwd = prefix.replaceAll('\\', '/');
    final rows = await (select(mediaItems)
          ..where((t) =>
              t.filePath.like('$prefix%') |
              t.filePath.like('$prefixFwd%'))
          ..where((t) => t.isDeleted.equals(false)))
        .get();
    var count = 0;
    for (final r in rows) {
      if (!await File(r.filePath).exists()) {
        await (update(mediaItems)..where((t) => t.id.equals(r.id)))
            .write(const MediaItemsCompanion(isMissing: Value(true)));
        count++;
      } else {
        await (update(mediaItems)..where((t) => t.id.equals(r.id)))
            .write(const MediaItemsCompanion(isMissing: Value(false)));
      }
    }
    return count;
  }

  /// 全库对账：检查所有未删除记录，标记 missing
  Future<int> reconcileAll() async {
    final rows = await (select(mediaItems)
          ..where((t) => t.isDeleted.equals(false)))
        .get();
    var count = 0;
    for (final r in rows) {
      final exists = await File(r.filePath).exists();
      final wantMissing = !exists;
      if (r.isMissing != wantMissing) {
        await (update(mediaItems)..where((t) => t.id.equals(r.id)))
            .write(MediaItemsCompanion(isMissing: Value(wantMissing)));
        if (wantMissing) count++;
      }
    }
    return count;
  }

  /// 全库重新分析区域：遍历所有带经纬度的 ExifData，
  /// 调用 [resolver] 把 lat/lng 反查为省市县，回写 province / district / cityName。
  ///
  /// 返回实际更新的行数。
  ///
  /// 调用方需自行保证 [resolver] 已 [RegionResolver.load] 完毕。
  Future<int> reAnalyzeRegions(
    Future<
                ({
                  String? province,
                  String? city,
                  String? district,
                  String? cityName
                })>
            Function(double lat, double lng)
        resolver,
  ) async {
    // 只筛选有经纬度且未软删的 EXIF 行
    final rows = await (select(exifDatas).join([
      innerJoin(mediaItems, mediaItems.id.equalsExp(exifDatas.mediaItemId)),
    ])
          ..where(
              exifDatas.latitude.isNotNull() & exifDatas.longitude.isNotNull())
          ..where(mediaItems.isDeleted.equals(false)))
        .get();
    var updated = 0;
    for (final row in rows) {
      final exif = row.readTable(exifDatas);
      final lat = exif.latitude;
      final lng = exif.longitude;
      if (lat == null || lng == null) continue;
      final r = await resolver(lat, lng);
      // 重新组装写入
      await (update(exifDatas)..where((e) => e.id.equals(exif.id))).write(
        ExifDatasCompanion(
          province: Value(r.province),
          district: Value(r.district),
          cityName: Value(r.cityName),
        ),
      );
      updated++;
    }
    return updated;
  }

  // ── 仪表盘统计 ──

  Future<List<FileSizeBucket>> getFileSizeBuckets() async {
    final rows = await (select(mediaItems)
          ..where((t) => t.isDeleted.equals(false))
          ..where((t) => t.isMissing.equals(false))
          ..where((t) => t.fileSizeBytes.isNotNull()))
        .get();
    final buckets = <String, int>{
      '< 1MB': 0,
      '1–5MB': 0,
      '5–20MB': 0,
      '20–100MB': 0,
      '> 100MB': 0,
    };
    for (final r in rows) {
      final mb = (r.fileSizeBytes ?? 0) / 1024 / 1024;
      if (mb < 1)
        buckets['< 1MB'] = buckets['< 1MB']! + 1;
      else if (mb < 5)
        buckets['1–5MB'] = buckets['1–5MB']! + 1;
      else if (mb < 20)
        buckets['5–20MB'] = buckets['5–20MB']! + 1;
      else if (mb < 100)
        buckets['20–100MB'] = buckets['20–100MB']! + 1;
      else
        buckets['> 100MB'] = buckets['> 100MB']! + 1;
    }
    return buckets.entries
        .map((e) => FileSizeBucket(label: e.key, count: e.value))
        .toList();
  }

  Future<Map<String, int>> getCityDistribution() async {
    // 关联到未软删的媒体项，软删的 EXIF 一起排除
    final rows = await (select(exifDatas).join([
      innerJoin(
        mediaItems,
        mediaItems.id.equalsExp(exifDatas.mediaItemId),
      )
    ])
          ..where(exifDatas.cityName.isNotNull())
          ..where(mediaItems.isDeleted.equals(false)))
        .get();
    final map = <String, int>{};
    for (final r in rows) {
      final city = r.readTable(exifDatas).cityName!;
      map[city] = (map[city] ?? 0) + 1;
    }
    return map;
  }

  Future<List<TagCloudItem>> getTagCloud() async {
    final allTags = await select(tags).get();
    return Future.wait(allTags.map((t) async {
      // 排除关联到软删媒体或已被标记为不活跃的标签计数
      final count = await (select(mediaTags).join([
        innerJoin(
          mediaItems,
          mediaItems.id.equalsExp(mediaTags.mediaItemId),
        )
      ])
            ..where(mediaTags.tagId.equals(t.id))
            ..where(mediaTags.active.equals(true))
            ..where(mediaItems.isDeleted.equals(false)))
          .get()
          .then((r) => r.length);
      return TagCloudItem(tag: t, count: count);
    }));
  }
}

// ─────────────────────────────────────────────
// 数据库连接（跨平台）
// ─────────────────────────────────────────────

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // 使用 PathHelper 获取安装目录下的数据路径
    await PathHelper.instance.initialize();
    final dbPath = PathHelper.instance.databasePath;
    // 在后台 isolate 中运行数据库，不阻塞主线程
    return NativeDatabase.createInBackground(File(dbPath));
  });
}

// ─────────────────────────────────────────────
// 视图模型
// ─────────────────────────────────────────────

class MediaItemWithMeta {
  final MediaItem item;
  final ExifData? exif;
  final List<Tag> tags;
  const MediaItemWithMeta({
    required this.item,
    required this.exif,
    required this.tags,
  });
}

class FileSizeBucket {
  final String label;
  final int count;
  const FileSizeBucket({required this.label, required this.count});
}

class TagCloudItem {
  final Tag tag;
  final int count;
  const TagCloudItem({required this.tag, required this.count});
}

class FolderBucket {
  final String folder;
  final int count;
  const FolderBucket({required this.folder, required this.count});
}

/// 文件夹树节点（用于层级导航）
class FolderTreeNode {
  final String path; // 完整绝对路径
  final String name; // 显示名（basename）
  final int fileCount; // 直接包含的文件数（不含子目录）
  final List<FolderTreeNode> children;
  final bool expanded; // UI 状态：是否展开
  const FolderTreeNode({
    required this.path,
    required this.name,
    this.fileCount = 0,
    this.children = const [],
    this.expanded = false,
  });

  /// 子节点按 name 排序
  FolderTreeNode copyWithSortedChildren() {
    final sorted = List<FolderTreeNode>.from(children)
      ..sort((a, b) => a.name.compareTo(b.name));
    return FolderTreeNode(
      path: path,
      name: name,
      fileCount: fileCount,
      children: sorted.map((c) => c.copyWithSortedChildren()).toList(),
      expanded: expanded,
    );
  }

  /// 总文件数（递归）
  int get totalCount =>
      fileCount + children.fold<int>(0, (s, c) => s + c.totalCount);
}

/// 子文件夹条目（右侧内容区虚拟目录卡片）
class SubFolderEntry {
  final String path;
  final String name;
  final int fileCount;
  const SubFolderEntry(
      {required this.path, required this.name, required this.fileCount});
}
