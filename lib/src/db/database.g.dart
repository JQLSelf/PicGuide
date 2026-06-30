// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $MediaItemsTable extends MediaItems
    with TableInfo<$MediaItemsTable, MediaItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _fileNameMeta =
      const VerificationMeta('fileName');
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
      'file_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fileTypeMeta =
      const VerificationMeta('fileType');
  @override
  late final GeneratedColumn<String> fileType = GeneratedColumn<String>(
      'file_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _mimeTypeMeta =
      const VerificationMeta('mimeType');
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
      'mime_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _fileSizeBytesMeta =
      const VerificationMeta('fileSizeBytes');
  @override
  late final GeneratedColumn<int> fileSizeBytes = GeneratedColumn<int>(
      'file_size_bytes', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _fileModifiedAtMeta =
      const VerificationMeta('fileModifiedAt');
  @override
  late final GeneratedColumn<DateTime> fileModifiedAt =
      GeneratedColumn<DateTime>('file_modified_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _indexedAtMeta =
      const VerificationMeta('indexedAt');
  @override
  late final GeneratedColumn<DateTime> indexedAt = GeneratedColumn<DateTime>(
      'indexed_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _thumbnailPathMeta =
      const VerificationMeta('thumbnailPath');
  @override
  late final GeneratedColumn<String> thumbnailPath = GeneratedColumn<String>(
      'thumbnail_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _md5Meta = const VerificationMeta('md5');
  @override
  late final GeneratedColumn<String> md5 = GeneratedColumn<String>(
      'md5', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isDeletedMeta =
      const VerificationMeta('isDeleted');
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
      'is_deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isMissingMeta =
      const VerificationMeta('isMissing');
  @override
  late final GeneratedColumn<bool> isMissing = GeneratedColumn<bool>(
      'is_missing', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_missing" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        filePath,
        fileName,
        fileType,
        mimeType,
        fileSizeBytes,
        fileModifiedAt,
        indexedAt,
        thumbnailPath,
        md5,
        isDeleted,
        isMissing
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_items';
  @override
  VerificationContext validateIntegrity(Insertable<MediaItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(_fileNameMeta,
          fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta));
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('file_type')) {
      context.handle(_fileTypeMeta,
          fileType.isAcceptableOrUnknown(data['file_type']!, _fileTypeMeta));
    } else if (isInserting) {
      context.missing(_fileTypeMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(_mimeTypeMeta,
          mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta));
    }
    if (data.containsKey('file_size_bytes')) {
      context.handle(
          _fileSizeBytesMeta,
          fileSizeBytes.isAcceptableOrUnknown(
              data['file_size_bytes']!, _fileSizeBytesMeta));
    }
    if (data.containsKey('file_modified_at')) {
      context.handle(
          _fileModifiedAtMeta,
          fileModifiedAt.isAcceptableOrUnknown(
              data['file_modified_at']!, _fileModifiedAtMeta));
    }
    if (data.containsKey('indexed_at')) {
      context.handle(_indexedAtMeta,
          indexedAt.isAcceptableOrUnknown(data['indexed_at']!, _indexedAtMeta));
    }
    if (data.containsKey('thumbnail_path')) {
      context.handle(
          _thumbnailPathMeta,
          thumbnailPath.isAcceptableOrUnknown(
              data['thumbnail_path']!, _thumbnailPathMeta));
    }
    if (data.containsKey('md5')) {
      context.handle(
          _md5Meta, md5.isAcceptableOrUnknown(data['md5']!, _md5Meta));
    }
    if (data.containsKey('is_deleted')) {
      context.handle(_isDeletedMeta,
          isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta));
    }
    if (data.containsKey('is_missing')) {
      context.handle(_isMissingMeta,
          isMissing.isAcceptableOrUnknown(data['is_missing']!, _isMissingMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MediaItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaItem(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path'])!,
      fileName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_name'])!,
      fileType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_type'])!,
      mimeType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mime_type']),
      fileSizeBytes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}file_size_bytes']),
      fileModifiedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}file_modified_at']),
      indexedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}indexed_at'])!,
      thumbnailPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}thumbnail_path']),
      md5: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}md5']),
      isDeleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_deleted'])!,
      isMissing: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_missing'])!,
    );
  }

  @override
  $MediaItemsTable createAlias(String alias) {
    return $MediaItemsTable(attachedDatabase, alias);
  }
}

class MediaItem extends DataClass implements Insertable<MediaItem> {
  final int id;
  final String filePath;
  final String fileName;
  final String fileType;
  final String? mimeType;
  final int? fileSizeBytes;
  final DateTime? fileModifiedAt;
  final DateTime indexedAt;
  final String? thumbnailPath;

  /// MD5 哈希，用于去重与内容一致性校验
  final String? md5;

  /// 文件是否已从归档中移除（软删除）
  final bool isDeleted;

  /// 文件是否在磁盘上缺失（对账发现）
  final bool isMissing;
  const MediaItem(
      {required this.id,
      required this.filePath,
      required this.fileName,
      required this.fileType,
      this.mimeType,
      this.fileSizeBytes,
      this.fileModifiedAt,
      required this.indexedAt,
      this.thumbnailPath,
      this.md5,
      required this.isDeleted,
      required this.isMissing});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['file_path'] = Variable<String>(filePath);
    map['file_name'] = Variable<String>(fileName);
    map['file_type'] = Variable<String>(fileType);
    if (!nullToAbsent || mimeType != null) {
      map['mime_type'] = Variable<String>(mimeType);
    }
    if (!nullToAbsent || fileSizeBytes != null) {
      map['file_size_bytes'] = Variable<int>(fileSizeBytes);
    }
    if (!nullToAbsent || fileModifiedAt != null) {
      map['file_modified_at'] = Variable<DateTime>(fileModifiedAt);
    }
    map['indexed_at'] = Variable<DateTime>(indexedAt);
    if (!nullToAbsent || thumbnailPath != null) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath);
    }
    if (!nullToAbsent || md5 != null) {
      map['md5'] = Variable<String>(md5);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['is_missing'] = Variable<bool>(isMissing);
    return map;
  }

  MediaItemsCompanion toCompanion(bool nullToAbsent) {
    return MediaItemsCompanion(
      id: Value(id),
      filePath: Value(filePath),
      fileName: Value(fileName),
      fileType: Value(fileType),
      mimeType: mimeType == null && nullToAbsent
          ? const Value.absent()
          : Value(mimeType),
      fileSizeBytes: fileSizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(fileSizeBytes),
      fileModifiedAt: fileModifiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(fileModifiedAt),
      indexedAt: Value(indexedAt),
      thumbnailPath: thumbnailPath == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailPath),
      md5: md5 == null && nullToAbsent ? const Value.absent() : Value(md5),
      isDeleted: Value(isDeleted),
      isMissing: Value(isMissing),
    );
  }

  factory MediaItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaItem(
      id: serializer.fromJson<int>(json['id']),
      filePath: serializer.fromJson<String>(json['filePath']),
      fileName: serializer.fromJson<String>(json['fileName']),
      fileType: serializer.fromJson<String>(json['fileType']),
      mimeType: serializer.fromJson<String?>(json['mimeType']),
      fileSizeBytes: serializer.fromJson<int?>(json['fileSizeBytes']),
      fileModifiedAt: serializer.fromJson<DateTime?>(json['fileModifiedAt']),
      indexedAt: serializer.fromJson<DateTime>(json['indexedAt']),
      thumbnailPath: serializer.fromJson<String?>(json['thumbnailPath']),
      md5: serializer.fromJson<String?>(json['md5']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      isMissing: serializer.fromJson<bool>(json['isMissing']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'filePath': serializer.toJson<String>(filePath),
      'fileName': serializer.toJson<String>(fileName),
      'fileType': serializer.toJson<String>(fileType),
      'mimeType': serializer.toJson<String?>(mimeType),
      'fileSizeBytes': serializer.toJson<int?>(fileSizeBytes),
      'fileModifiedAt': serializer.toJson<DateTime?>(fileModifiedAt),
      'indexedAt': serializer.toJson<DateTime>(indexedAt),
      'thumbnailPath': serializer.toJson<String?>(thumbnailPath),
      'md5': serializer.toJson<String?>(md5),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'isMissing': serializer.toJson<bool>(isMissing),
    };
  }

  MediaItem copyWith(
          {int? id,
          String? filePath,
          String? fileName,
          String? fileType,
          Value<String?> mimeType = const Value.absent(),
          Value<int?> fileSizeBytes = const Value.absent(),
          Value<DateTime?> fileModifiedAt = const Value.absent(),
          DateTime? indexedAt,
          Value<String?> thumbnailPath = const Value.absent(),
          Value<String?> md5 = const Value.absent(),
          bool? isDeleted,
          bool? isMissing}) =>
      MediaItem(
        id: id ?? this.id,
        filePath: filePath ?? this.filePath,
        fileName: fileName ?? this.fileName,
        fileType: fileType ?? this.fileType,
        mimeType: mimeType.present ? mimeType.value : this.mimeType,
        fileSizeBytes:
            fileSizeBytes.present ? fileSizeBytes.value : this.fileSizeBytes,
        fileModifiedAt:
            fileModifiedAt.present ? fileModifiedAt.value : this.fileModifiedAt,
        indexedAt: indexedAt ?? this.indexedAt,
        thumbnailPath:
            thumbnailPath.present ? thumbnailPath.value : this.thumbnailPath,
        md5: md5.present ? md5.value : this.md5,
        isDeleted: isDeleted ?? this.isDeleted,
        isMissing: isMissing ?? this.isMissing,
      );
  MediaItem copyWithCompanion(MediaItemsCompanion data) {
    return MediaItem(
      id: data.id.present ? data.id.value : this.id,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      fileType: data.fileType.present ? data.fileType.value : this.fileType,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      fileSizeBytes: data.fileSizeBytes.present
          ? data.fileSizeBytes.value
          : this.fileSizeBytes,
      fileModifiedAt: data.fileModifiedAt.present
          ? data.fileModifiedAt.value
          : this.fileModifiedAt,
      indexedAt: data.indexedAt.present ? data.indexedAt.value : this.indexedAt,
      thumbnailPath: data.thumbnailPath.present
          ? data.thumbnailPath.value
          : this.thumbnailPath,
      md5: data.md5.present ? data.md5.value : this.md5,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      isMissing: data.isMissing.present ? data.isMissing.value : this.isMissing,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaItem(')
          ..write('id: $id, ')
          ..write('filePath: $filePath, ')
          ..write('fileName: $fileName, ')
          ..write('fileType: $fileType, ')
          ..write('mimeType: $mimeType, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('fileModifiedAt: $fileModifiedAt, ')
          ..write('indexedAt: $indexedAt, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('md5: $md5, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('isMissing: $isMissing')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      filePath,
      fileName,
      fileType,
      mimeType,
      fileSizeBytes,
      fileModifiedAt,
      indexedAt,
      thumbnailPath,
      md5,
      isDeleted,
      isMissing);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaItem &&
          other.id == this.id &&
          other.filePath == this.filePath &&
          other.fileName == this.fileName &&
          other.fileType == this.fileType &&
          other.mimeType == this.mimeType &&
          other.fileSizeBytes == this.fileSizeBytes &&
          other.fileModifiedAt == this.fileModifiedAt &&
          other.indexedAt == this.indexedAt &&
          other.thumbnailPath == this.thumbnailPath &&
          other.md5 == this.md5 &&
          other.isDeleted == this.isDeleted &&
          other.isMissing == this.isMissing);
}

class MediaItemsCompanion extends UpdateCompanion<MediaItem> {
  final Value<int> id;
  final Value<String> filePath;
  final Value<String> fileName;
  final Value<String> fileType;
  final Value<String?> mimeType;
  final Value<int?> fileSizeBytes;
  final Value<DateTime?> fileModifiedAt;
  final Value<DateTime> indexedAt;
  final Value<String?> thumbnailPath;
  final Value<String?> md5;
  final Value<bool> isDeleted;
  final Value<bool> isMissing;
  const MediaItemsCompanion({
    this.id = const Value.absent(),
    this.filePath = const Value.absent(),
    this.fileName = const Value.absent(),
    this.fileType = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.fileSizeBytes = const Value.absent(),
    this.fileModifiedAt = const Value.absent(),
    this.indexedAt = const Value.absent(),
    this.thumbnailPath = const Value.absent(),
    this.md5 = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.isMissing = const Value.absent(),
  });
  MediaItemsCompanion.insert({
    this.id = const Value.absent(),
    required String filePath,
    required String fileName,
    required String fileType,
    this.mimeType = const Value.absent(),
    this.fileSizeBytes = const Value.absent(),
    this.fileModifiedAt = const Value.absent(),
    this.indexedAt = const Value.absent(),
    this.thumbnailPath = const Value.absent(),
    this.md5 = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.isMissing = const Value.absent(),
  })  : filePath = Value(filePath),
        fileName = Value(fileName),
        fileType = Value(fileType);
  static Insertable<MediaItem> custom({
    Expression<int>? id,
    Expression<String>? filePath,
    Expression<String>? fileName,
    Expression<String>? fileType,
    Expression<String>? mimeType,
    Expression<int>? fileSizeBytes,
    Expression<DateTime>? fileModifiedAt,
    Expression<DateTime>? indexedAt,
    Expression<String>? thumbnailPath,
    Expression<String>? md5,
    Expression<bool>? isDeleted,
    Expression<bool>? isMissing,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (filePath != null) 'file_path': filePath,
      if (fileName != null) 'file_name': fileName,
      if (fileType != null) 'file_type': fileType,
      if (mimeType != null) 'mime_type': mimeType,
      if (fileSizeBytes != null) 'file_size_bytes': fileSizeBytes,
      if (fileModifiedAt != null) 'file_modified_at': fileModifiedAt,
      if (indexedAt != null) 'indexed_at': indexedAt,
      if (thumbnailPath != null) 'thumbnail_path': thumbnailPath,
      if (md5 != null) 'md5': md5,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (isMissing != null) 'is_missing': isMissing,
    });
  }

  MediaItemsCompanion copyWith(
      {Value<int>? id,
      Value<String>? filePath,
      Value<String>? fileName,
      Value<String>? fileType,
      Value<String?>? mimeType,
      Value<int?>? fileSizeBytes,
      Value<DateTime?>? fileModifiedAt,
      Value<DateTime>? indexedAt,
      Value<String?>? thumbnailPath,
      Value<String?>? md5,
      Value<bool>? isDeleted,
      Value<bool>? isMissing}) {
    return MediaItemsCompanion(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      mimeType: mimeType ?? this.mimeType,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      fileModifiedAt: fileModifiedAt ?? this.fileModifiedAt,
      indexedAt: indexedAt ?? this.indexedAt,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      md5: md5 ?? this.md5,
      isDeleted: isDeleted ?? this.isDeleted,
      isMissing: isMissing ?? this.isMissing,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (fileType.present) {
      map['file_type'] = Variable<String>(fileType.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (fileSizeBytes.present) {
      map['file_size_bytes'] = Variable<int>(fileSizeBytes.value);
    }
    if (fileModifiedAt.present) {
      map['file_modified_at'] = Variable<DateTime>(fileModifiedAt.value);
    }
    if (indexedAt.present) {
      map['indexed_at'] = Variable<DateTime>(indexedAt.value);
    }
    if (thumbnailPath.present) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath.value);
    }
    if (md5.present) {
      map['md5'] = Variable<String>(md5.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (isMissing.present) {
      map['is_missing'] = Variable<bool>(isMissing.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaItemsCompanion(')
          ..write('id: $id, ')
          ..write('filePath: $filePath, ')
          ..write('fileName: $fileName, ')
          ..write('fileType: $fileType, ')
          ..write('mimeType: $mimeType, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('fileModifiedAt: $fileModifiedAt, ')
          ..write('indexedAt: $indexedAt, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('md5: $md5, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('isMissing: $isMissing')
          ..write(')'))
        .toString();
  }
}

class $ExifDatasTable extends ExifDatas
    with TableInfo<$ExifDatasTable, ExifData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExifDatasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _mediaItemIdMeta =
      const VerificationMeta('mediaItemId');
  @override
  late final GeneratedColumn<int> mediaItemId = GeneratedColumn<int>(
      'media_item_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES media_items (id) ON DELETE CASCADE'));
  static const VerificationMeta _makeMeta = const VerificationMeta('make');
  @override
  late final GeneratedColumn<String> make = GeneratedColumn<String>(
      'make', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
      'model', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _softwareMeta =
      const VerificationMeta('software');
  @override
  late final GeneratedColumn<String> software = GeneratedColumn<String>(
      'software', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _dateTakenMeta =
      const VerificationMeta('dateTaken');
  @override
  late final GeneratedColumn<DateTime> dateTaken = GeneratedColumn<DateTime>(
      'date_taken', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _latitudeMeta =
      const VerificationMeta('latitude');
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
      'latitude', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _longitudeMeta =
      const VerificationMeta('longitude');
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
      'longitude', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _cityNameMeta =
      const VerificationMeta('cityName');
  @override
  late final GeneratedColumn<String> cityName = GeneratedColumn<String>(
      'city_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _provinceMeta =
      const VerificationMeta('province');
  @override
  late final GeneratedColumn<String> province = GeneratedColumn<String>(
      'province', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _districtMeta =
      const VerificationMeta('district');
  @override
  late final GeneratedColumn<String> district = GeneratedColumn<String>(
      'district', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isoSpeedMeta =
      const VerificationMeta('isoSpeed');
  @override
  late final GeneratedColumn<String> isoSpeed = GeneratedColumn<String>(
      'iso_speed', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _fNumberMeta =
      const VerificationMeta('fNumber');
  @override
  late final GeneratedColumn<String> fNumber = GeneratedColumn<String>(
      'f_number', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _exposureTimeMeta =
      const VerificationMeta('exposureTime');
  @override
  late final GeneratedColumn<String> exposureTime = GeneratedColumn<String>(
      'exposure_time', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _focalLengthMeta =
      const VerificationMeta('focalLength');
  @override
  late final GeneratedColumn<String> focalLength = GeneratedColumn<String>(
      'focal_length', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _imageWidthMeta =
      const VerificationMeta('imageWidth');
  @override
  late final GeneratedColumn<int> imageWidth = GeneratedColumn<int>(
      'image_width', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _imageHeightMeta =
      const VerificationMeta('imageHeight');
  @override
  late final GeneratedColumn<int> imageHeight = GeneratedColumn<int>(
      'image_height', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _orientationMeta =
      const VerificationMeta('orientation');
  @override
  late final GeneratedColumn<String> orientation = GeneratedColumn<String>(
      'orientation', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _rawJsonMeta =
      const VerificationMeta('rawJson');
  @override
  late final GeneratedColumn<String> rawJson = GeneratedColumn<String>(
      'raw_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        mediaItemId,
        make,
        model,
        software,
        dateTaken,
        latitude,
        longitude,
        cityName,
        province,
        district,
        isoSpeed,
        fNumber,
        exposureTime,
        focalLength,
        imageWidth,
        imageHeight,
        orientation,
        rawJson
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exif_datas';
  @override
  VerificationContext validateIntegrity(Insertable<ExifData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('media_item_id')) {
      context.handle(
          _mediaItemIdMeta,
          mediaItemId.isAcceptableOrUnknown(
              data['media_item_id']!, _mediaItemIdMeta));
    } else if (isInserting) {
      context.missing(_mediaItemIdMeta);
    }
    if (data.containsKey('make')) {
      context.handle(
          _makeMeta, make.isAcceptableOrUnknown(data['make']!, _makeMeta));
    }
    if (data.containsKey('model')) {
      context.handle(
          _modelMeta, model.isAcceptableOrUnknown(data['model']!, _modelMeta));
    }
    if (data.containsKey('software')) {
      context.handle(_softwareMeta,
          software.isAcceptableOrUnknown(data['software']!, _softwareMeta));
    }
    if (data.containsKey('date_taken')) {
      context.handle(_dateTakenMeta,
          dateTaken.isAcceptableOrUnknown(data['date_taken']!, _dateTakenMeta));
    }
    if (data.containsKey('latitude')) {
      context.handle(_latitudeMeta,
          latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta));
    }
    if (data.containsKey('longitude')) {
      context.handle(_longitudeMeta,
          longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta));
    }
    if (data.containsKey('city_name')) {
      context.handle(_cityNameMeta,
          cityName.isAcceptableOrUnknown(data['city_name']!, _cityNameMeta));
    }
    if (data.containsKey('province')) {
      context.handle(_provinceMeta,
          province.isAcceptableOrUnknown(data['province']!, _provinceMeta));
    }
    if (data.containsKey('district')) {
      context.handle(_districtMeta,
          district.isAcceptableOrUnknown(data['district']!, _districtMeta));
    }
    if (data.containsKey('iso_speed')) {
      context.handle(_isoSpeedMeta,
          isoSpeed.isAcceptableOrUnknown(data['iso_speed']!, _isoSpeedMeta));
    }
    if (data.containsKey('f_number')) {
      context.handle(_fNumberMeta,
          fNumber.isAcceptableOrUnknown(data['f_number']!, _fNumberMeta));
    }
    if (data.containsKey('exposure_time')) {
      context.handle(
          _exposureTimeMeta,
          exposureTime.isAcceptableOrUnknown(
              data['exposure_time']!, _exposureTimeMeta));
    }
    if (data.containsKey('focal_length')) {
      context.handle(
          _focalLengthMeta,
          focalLength.isAcceptableOrUnknown(
              data['focal_length']!, _focalLengthMeta));
    }
    if (data.containsKey('image_width')) {
      context.handle(
          _imageWidthMeta,
          imageWidth.isAcceptableOrUnknown(
              data['image_width']!, _imageWidthMeta));
    }
    if (data.containsKey('image_height')) {
      context.handle(
          _imageHeightMeta,
          imageHeight.isAcceptableOrUnknown(
              data['image_height']!, _imageHeightMeta));
    }
    if (data.containsKey('orientation')) {
      context.handle(
          _orientationMeta,
          orientation.isAcceptableOrUnknown(
              data['orientation']!, _orientationMeta));
    }
    if (data.containsKey('raw_json')) {
      context.handle(_rawJsonMeta,
          rawJson.isAcceptableOrUnknown(data['raw_json']!, _rawJsonMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExifData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExifData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      mediaItemId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}media_item_id'])!,
      make: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}make']),
      model: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}model']),
      software: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}software']),
      dateTaken: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date_taken']),
      latitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}latitude']),
      longitude: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}longitude']),
      cityName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}city_name']),
      province: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}province']),
      district: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}district']),
      isoSpeed: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}iso_speed']),
      fNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}f_number']),
      exposureTime: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}exposure_time']),
      focalLength: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}focal_length']),
      imageWidth: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}image_width']),
      imageHeight: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}image_height']),
      orientation: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}orientation']),
      rawJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}raw_json']),
    );
  }

  @override
  $ExifDatasTable createAlias(String alias) {
    return $ExifDatasTable(attachedDatabase, alias);
  }
}

class ExifData extends DataClass implements Insertable<ExifData> {
  final int id;
  final int mediaItemId;
  final String? make;
  final String? model;
  final String? software;
  final DateTime? dateTaken;
  final double? latitude;
  final double? longitude;
  final String? cityName;

  /// 省 / 自治区 / 直辖市（离线 RegionResolver 写入）
  final String? province;

  /// 县 / 区（当前数据源未含，留作扩展）
  final String? district;
  final String? isoSpeed;
  final String? fNumber;
  final String? exposureTime;
  final String? focalLength;
  final int? imageWidth;
  final int? imageHeight;
  final String? orientation;
  final String? rawJson;
  const ExifData(
      {required this.id,
      required this.mediaItemId,
      this.make,
      this.model,
      this.software,
      this.dateTaken,
      this.latitude,
      this.longitude,
      this.cityName,
      this.province,
      this.district,
      this.isoSpeed,
      this.fNumber,
      this.exposureTime,
      this.focalLength,
      this.imageWidth,
      this.imageHeight,
      this.orientation,
      this.rawJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['media_item_id'] = Variable<int>(mediaItemId);
    if (!nullToAbsent || make != null) {
      map['make'] = Variable<String>(make);
    }
    if (!nullToAbsent || model != null) {
      map['model'] = Variable<String>(model);
    }
    if (!nullToAbsent || software != null) {
      map['software'] = Variable<String>(software);
    }
    if (!nullToAbsent || dateTaken != null) {
      map['date_taken'] = Variable<DateTime>(dateTaken);
    }
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    if (!nullToAbsent || cityName != null) {
      map['city_name'] = Variable<String>(cityName);
    }
    if (!nullToAbsent || province != null) {
      map['province'] = Variable<String>(province);
    }
    if (!nullToAbsent || district != null) {
      map['district'] = Variable<String>(district);
    }
    if (!nullToAbsent || isoSpeed != null) {
      map['iso_speed'] = Variable<String>(isoSpeed);
    }
    if (!nullToAbsent || fNumber != null) {
      map['f_number'] = Variable<String>(fNumber);
    }
    if (!nullToAbsent || exposureTime != null) {
      map['exposure_time'] = Variable<String>(exposureTime);
    }
    if (!nullToAbsent || focalLength != null) {
      map['focal_length'] = Variable<String>(focalLength);
    }
    if (!nullToAbsent || imageWidth != null) {
      map['image_width'] = Variable<int>(imageWidth);
    }
    if (!nullToAbsent || imageHeight != null) {
      map['image_height'] = Variable<int>(imageHeight);
    }
    if (!nullToAbsent || orientation != null) {
      map['orientation'] = Variable<String>(orientation);
    }
    if (!nullToAbsent || rawJson != null) {
      map['raw_json'] = Variable<String>(rawJson);
    }
    return map;
  }

  ExifDatasCompanion toCompanion(bool nullToAbsent) {
    return ExifDatasCompanion(
      id: Value(id),
      mediaItemId: Value(mediaItemId),
      make: make == null && nullToAbsent ? const Value.absent() : Value(make),
      model:
          model == null && nullToAbsent ? const Value.absent() : Value(model),
      software: software == null && nullToAbsent
          ? const Value.absent()
          : Value(software),
      dateTaken: dateTaken == null && nullToAbsent
          ? const Value.absent()
          : Value(dateTaken),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
      cityName: cityName == null && nullToAbsent
          ? const Value.absent()
          : Value(cityName),
      province: province == null && nullToAbsent
          ? const Value.absent()
          : Value(province),
      district: district == null && nullToAbsent
          ? const Value.absent()
          : Value(district),
      isoSpeed: isoSpeed == null && nullToAbsent
          ? const Value.absent()
          : Value(isoSpeed),
      fNumber: fNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(fNumber),
      exposureTime: exposureTime == null && nullToAbsent
          ? const Value.absent()
          : Value(exposureTime),
      focalLength: focalLength == null && nullToAbsent
          ? const Value.absent()
          : Value(focalLength),
      imageWidth: imageWidth == null && nullToAbsent
          ? const Value.absent()
          : Value(imageWidth),
      imageHeight: imageHeight == null && nullToAbsent
          ? const Value.absent()
          : Value(imageHeight),
      orientation: orientation == null && nullToAbsent
          ? const Value.absent()
          : Value(orientation),
      rawJson: rawJson == null && nullToAbsent
          ? const Value.absent()
          : Value(rawJson),
    );
  }

  factory ExifData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExifData(
      id: serializer.fromJson<int>(json['id']),
      mediaItemId: serializer.fromJson<int>(json['mediaItemId']),
      make: serializer.fromJson<String?>(json['make']),
      model: serializer.fromJson<String?>(json['model']),
      software: serializer.fromJson<String?>(json['software']),
      dateTaken: serializer.fromJson<DateTime?>(json['dateTaken']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
      cityName: serializer.fromJson<String?>(json['cityName']),
      province: serializer.fromJson<String?>(json['province']),
      district: serializer.fromJson<String?>(json['district']),
      isoSpeed: serializer.fromJson<String?>(json['isoSpeed']),
      fNumber: serializer.fromJson<String?>(json['fNumber']),
      exposureTime: serializer.fromJson<String?>(json['exposureTime']),
      focalLength: serializer.fromJson<String?>(json['focalLength']),
      imageWidth: serializer.fromJson<int?>(json['imageWidth']),
      imageHeight: serializer.fromJson<int?>(json['imageHeight']),
      orientation: serializer.fromJson<String?>(json['orientation']),
      rawJson: serializer.fromJson<String?>(json['rawJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'mediaItemId': serializer.toJson<int>(mediaItemId),
      'make': serializer.toJson<String?>(make),
      'model': serializer.toJson<String?>(model),
      'software': serializer.toJson<String?>(software),
      'dateTaken': serializer.toJson<DateTime?>(dateTaken),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
      'cityName': serializer.toJson<String?>(cityName),
      'province': serializer.toJson<String?>(province),
      'district': serializer.toJson<String?>(district),
      'isoSpeed': serializer.toJson<String?>(isoSpeed),
      'fNumber': serializer.toJson<String?>(fNumber),
      'exposureTime': serializer.toJson<String?>(exposureTime),
      'focalLength': serializer.toJson<String?>(focalLength),
      'imageWidth': serializer.toJson<int?>(imageWidth),
      'imageHeight': serializer.toJson<int?>(imageHeight),
      'orientation': serializer.toJson<String?>(orientation),
      'rawJson': serializer.toJson<String?>(rawJson),
    };
  }

  ExifData copyWith(
          {int? id,
          int? mediaItemId,
          Value<String?> make = const Value.absent(),
          Value<String?> model = const Value.absent(),
          Value<String?> software = const Value.absent(),
          Value<DateTime?> dateTaken = const Value.absent(),
          Value<double?> latitude = const Value.absent(),
          Value<double?> longitude = const Value.absent(),
          Value<String?> cityName = const Value.absent(),
          Value<String?> province = const Value.absent(),
          Value<String?> district = const Value.absent(),
          Value<String?> isoSpeed = const Value.absent(),
          Value<String?> fNumber = const Value.absent(),
          Value<String?> exposureTime = const Value.absent(),
          Value<String?> focalLength = const Value.absent(),
          Value<int?> imageWidth = const Value.absent(),
          Value<int?> imageHeight = const Value.absent(),
          Value<String?> orientation = const Value.absent(),
          Value<String?> rawJson = const Value.absent()}) =>
      ExifData(
        id: id ?? this.id,
        mediaItemId: mediaItemId ?? this.mediaItemId,
        make: make.present ? make.value : this.make,
        model: model.present ? model.value : this.model,
        software: software.present ? software.value : this.software,
        dateTaken: dateTaken.present ? dateTaken.value : this.dateTaken,
        latitude: latitude.present ? latitude.value : this.latitude,
        longitude: longitude.present ? longitude.value : this.longitude,
        cityName: cityName.present ? cityName.value : this.cityName,
        province: province.present ? province.value : this.province,
        district: district.present ? district.value : this.district,
        isoSpeed: isoSpeed.present ? isoSpeed.value : this.isoSpeed,
        fNumber: fNumber.present ? fNumber.value : this.fNumber,
        exposureTime:
            exposureTime.present ? exposureTime.value : this.exposureTime,
        focalLength: focalLength.present ? focalLength.value : this.focalLength,
        imageWidth: imageWidth.present ? imageWidth.value : this.imageWidth,
        imageHeight: imageHeight.present ? imageHeight.value : this.imageHeight,
        orientation: orientation.present ? orientation.value : this.orientation,
        rawJson: rawJson.present ? rawJson.value : this.rawJson,
      );
  ExifData copyWithCompanion(ExifDatasCompanion data) {
    return ExifData(
      id: data.id.present ? data.id.value : this.id,
      mediaItemId:
          data.mediaItemId.present ? data.mediaItemId.value : this.mediaItemId,
      make: data.make.present ? data.make.value : this.make,
      model: data.model.present ? data.model.value : this.model,
      software: data.software.present ? data.software.value : this.software,
      dateTaken: data.dateTaken.present ? data.dateTaken.value : this.dateTaken,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      cityName: data.cityName.present ? data.cityName.value : this.cityName,
      province: data.province.present ? data.province.value : this.province,
      district: data.district.present ? data.district.value : this.district,
      isoSpeed: data.isoSpeed.present ? data.isoSpeed.value : this.isoSpeed,
      fNumber: data.fNumber.present ? data.fNumber.value : this.fNumber,
      exposureTime: data.exposureTime.present
          ? data.exposureTime.value
          : this.exposureTime,
      focalLength:
          data.focalLength.present ? data.focalLength.value : this.focalLength,
      imageWidth:
          data.imageWidth.present ? data.imageWidth.value : this.imageWidth,
      imageHeight:
          data.imageHeight.present ? data.imageHeight.value : this.imageHeight,
      orientation:
          data.orientation.present ? data.orientation.value : this.orientation,
      rawJson: data.rawJson.present ? data.rawJson.value : this.rawJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExifData(')
          ..write('id: $id, ')
          ..write('mediaItemId: $mediaItemId, ')
          ..write('make: $make, ')
          ..write('model: $model, ')
          ..write('software: $software, ')
          ..write('dateTaken: $dateTaken, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('cityName: $cityName, ')
          ..write('province: $province, ')
          ..write('district: $district, ')
          ..write('isoSpeed: $isoSpeed, ')
          ..write('fNumber: $fNumber, ')
          ..write('exposureTime: $exposureTime, ')
          ..write('focalLength: $focalLength, ')
          ..write('imageWidth: $imageWidth, ')
          ..write('imageHeight: $imageHeight, ')
          ..write('orientation: $orientation, ')
          ..write('rawJson: $rawJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      mediaItemId,
      make,
      model,
      software,
      dateTaken,
      latitude,
      longitude,
      cityName,
      province,
      district,
      isoSpeed,
      fNumber,
      exposureTime,
      focalLength,
      imageWidth,
      imageHeight,
      orientation,
      rawJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExifData &&
          other.id == this.id &&
          other.mediaItemId == this.mediaItemId &&
          other.make == this.make &&
          other.model == this.model &&
          other.software == this.software &&
          other.dateTaken == this.dateTaken &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.cityName == this.cityName &&
          other.province == this.province &&
          other.district == this.district &&
          other.isoSpeed == this.isoSpeed &&
          other.fNumber == this.fNumber &&
          other.exposureTime == this.exposureTime &&
          other.focalLength == this.focalLength &&
          other.imageWidth == this.imageWidth &&
          other.imageHeight == this.imageHeight &&
          other.orientation == this.orientation &&
          other.rawJson == this.rawJson);
}

class ExifDatasCompanion extends UpdateCompanion<ExifData> {
  final Value<int> id;
  final Value<int> mediaItemId;
  final Value<String?> make;
  final Value<String?> model;
  final Value<String?> software;
  final Value<DateTime?> dateTaken;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<String?> cityName;
  final Value<String?> province;
  final Value<String?> district;
  final Value<String?> isoSpeed;
  final Value<String?> fNumber;
  final Value<String?> exposureTime;
  final Value<String?> focalLength;
  final Value<int?> imageWidth;
  final Value<int?> imageHeight;
  final Value<String?> orientation;
  final Value<String?> rawJson;
  const ExifDatasCompanion({
    this.id = const Value.absent(),
    this.mediaItemId = const Value.absent(),
    this.make = const Value.absent(),
    this.model = const Value.absent(),
    this.software = const Value.absent(),
    this.dateTaken = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.cityName = const Value.absent(),
    this.province = const Value.absent(),
    this.district = const Value.absent(),
    this.isoSpeed = const Value.absent(),
    this.fNumber = const Value.absent(),
    this.exposureTime = const Value.absent(),
    this.focalLength = const Value.absent(),
    this.imageWidth = const Value.absent(),
    this.imageHeight = const Value.absent(),
    this.orientation = const Value.absent(),
    this.rawJson = const Value.absent(),
  });
  ExifDatasCompanion.insert({
    this.id = const Value.absent(),
    required int mediaItemId,
    this.make = const Value.absent(),
    this.model = const Value.absent(),
    this.software = const Value.absent(),
    this.dateTaken = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.cityName = const Value.absent(),
    this.province = const Value.absent(),
    this.district = const Value.absent(),
    this.isoSpeed = const Value.absent(),
    this.fNumber = const Value.absent(),
    this.exposureTime = const Value.absent(),
    this.focalLength = const Value.absent(),
    this.imageWidth = const Value.absent(),
    this.imageHeight = const Value.absent(),
    this.orientation = const Value.absent(),
    this.rawJson = const Value.absent(),
  }) : mediaItemId = Value(mediaItemId);
  static Insertable<ExifData> custom({
    Expression<int>? id,
    Expression<int>? mediaItemId,
    Expression<String>? make,
    Expression<String>? model,
    Expression<String>? software,
    Expression<DateTime>? dateTaken,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<String>? cityName,
    Expression<String>? province,
    Expression<String>? district,
    Expression<String>? isoSpeed,
    Expression<String>? fNumber,
    Expression<String>? exposureTime,
    Expression<String>? focalLength,
    Expression<int>? imageWidth,
    Expression<int>? imageHeight,
    Expression<String>? orientation,
    Expression<String>? rawJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mediaItemId != null) 'media_item_id': mediaItemId,
      if (make != null) 'make': make,
      if (model != null) 'model': model,
      if (software != null) 'software': software,
      if (dateTaken != null) 'date_taken': dateTaken,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (cityName != null) 'city_name': cityName,
      if (province != null) 'province': province,
      if (district != null) 'district': district,
      if (isoSpeed != null) 'iso_speed': isoSpeed,
      if (fNumber != null) 'f_number': fNumber,
      if (exposureTime != null) 'exposure_time': exposureTime,
      if (focalLength != null) 'focal_length': focalLength,
      if (imageWidth != null) 'image_width': imageWidth,
      if (imageHeight != null) 'image_height': imageHeight,
      if (orientation != null) 'orientation': orientation,
      if (rawJson != null) 'raw_json': rawJson,
    });
  }

  ExifDatasCompanion copyWith(
      {Value<int>? id,
      Value<int>? mediaItemId,
      Value<String?>? make,
      Value<String?>? model,
      Value<String?>? software,
      Value<DateTime?>? dateTaken,
      Value<double?>? latitude,
      Value<double?>? longitude,
      Value<String?>? cityName,
      Value<String?>? province,
      Value<String?>? district,
      Value<String?>? isoSpeed,
      Value<String?>? fNumber,
      Value<String?>? exposureTime,
      Value<String?>? focalLength,
      Value<int?>? imageWidth,
      Value<int?>? imageHeight,
      Value<String?>? orientation,
      Value<String?>? rawJson}) {
    return ExifDatasCompanion(
      id: id ?? this.id,
      mediaItemId: mediaItemId ?? this.mediaItemId,
      make: make ?? this.make,
      model: model ?? this.model,
      software: software ?? this.software,
      dateTaken: dateTaken ?? this.dateTaken,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      cityName: cityName ?? this.cityName,
      province: province ?? this.province,
      district: district ?? this.district,
      isoSpeed: isoSpeed ?? this.isoSpeed,
      fNumber: fNumber ?? this.fNumber,
      exposureTime: exposureTime ?? this.exposureTime,
      focalLength: focalLength ?? this.focalLength,
      imageWidth: imageWidth ?? this.imageWidth,
      imageHeight: imageHeight ?? this.imageHeight,
      orientation: orientation ?? this.orientation,
      rawJson: rawJson ?? this.rawJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (mediaItemId.present) {
      map['media_item_id'] = Variable<int>(mediaItemId.value);
    }
    if (make.present) {
      map['make'] = Variable<String>(make.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (software.present) {
      map['software'] = Variable<String>(software.value);
    }
    if (dateTaken.present) {
      map['date_taken'] = Variable<DateTime>(dateTaken.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (cityName.present) {
      map['city_name'] = Variable<String>(cityName.value);
    }
    if (province.present) {
      map['province'] = Variable<String>(province.value);
    }
    if (district.present) {
      map['district'] = Variable<String>(district.value);
    }
    if (isoSpeed.present) {
      map['iso_speed'] = Variable<String>(isoSpeed.value);
    }
    if (fNumber.present) {
      map['f_number'] = Variable<String>(fNumber.value);
    }
    if (exposureTime.present) {
      map['exposure_time'] = Variable<String>(exposureTime.value);
    }
    if (focalLength.present) {
      map['focal_length'] = Variable<String>(focalLength.value);
    }
    if (imageWidth.present) {
      map['image_width'] = Variable<int>(imageWidth.value);
    }
    if (imageHeight.present) {
      map['image_height'] = Variable<int>(imageHeight.value);
    }
    if (orientation.present) {
      map['orientation'] = Variable<String>(orientation.value);
    }
    if (rawJson.present) {
      map['raw_json'] = Variable<String>(rawJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExifDatasCompanion(')
          ..write('id: $id, ')
          ..write('mediaItemId: $mediaItemId, ')
          ..write('make: $make, ')
          ..write('model: $model, ')
          ..write('software: $software, ')
          ..write('dateTaken: $dateTaken, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('cityName: $cityName, ')
          ..write('province: $province, ')
          ..write('district: $district, ')
          ..write('isoSpeed: $isoSpeed, ')
          ..write('fNumber: $fNumber, ')
          ..write('exposureTime: $exposureTime, ')
          ..write('focalLength: $focalLength, ')
          ..write('imageWidth: $imageWidth, ')
          ..write('imageHeight: $imageHeight, ')
          ..write('orientation: $orientation, ')
          ..write('rawJson: $rawJson')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, Tag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
      'color', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('#4A90D9'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [id, name, color, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(Insertable<Tag> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
          _colorMeta, color.isAcceptableOrUnknown(data['color']!, _colorMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Tag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tag(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      color: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}color'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class Tag extends DataClass implements Insertable<Tag> {
  final int id;
  final String name;
  final String color;
  final DateTime createdAt;
  const Tag(
      {required this.id,
      required this.name,
      required this.color,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['color'] = Variable<String>(color);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(
      id: Value(id),
      name: Value(name),
      color: Value(color),
      createdAt: Value(createdAt),
    );
  }

  factory Tag.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tag(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<String>(json['color']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<String>(color),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Tag copyWith({int? id, String? name, String? color, DateTime? createdAt}) =>
      Tag(
        id: id ?? this.id,
        name: name ?? this.name,
        color: color ?? this.color,
        createdAt: createdAt ?? this.createdAt,
      );
  Tag copyWithCompanion(TagsCompanion data) {
    return Tag(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tag(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, color, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tag &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color &&
          other.createdAt == this.createdAt);
}

class TagsCompanion extends UpdateCompanion<Tag> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> color;
  final Value<DateTime> createdAt;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TagsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.color = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Tag> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? color,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TagsCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String>? color,
      Value<DateTime>? createdAt}) {
    return TagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $MediaTagsTable extends MediaTags
    with TableInfo<$MediaTagsTable, MediaTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _mediaItemIdMeta =
      const VerificationMeta('mediaItemId');
  @override
  late final GeneratedColumn<int> mediaItemId = GeneratedColumn<int>(
      'media_item_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES media_items (id) ON DELETE CASCADE'));
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<int> tagId = GeneratedColumn<int>(
      'tag_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES tags (id) ON DELETE CASCADE'));
  static const VerificationMeta _activeMeta =
      const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
      'active', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultValue: const Constant(true));
  @override
  List<GeneratedColumn> get $columns => [mediaItemId, tagId, active];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_tags';
  @override
  VerificationContext validateIntegrity(Insertable<MediaTag> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('media_item_id')) {
      context.handle(
          _mediaItemIdMeta,
          mediaItemId.isAcceptableOrUnknown(
              data['media_item_id']!, _mediaItemIdMeta));
    } else if (isInserting) {
      context.missing(_mediaItemIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
          _tagIdMeta, tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta));
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    if (data.containsKey('active')) {
      context.handle(
          _activeMeta, active.isAcceptableOrUnknown(data['active']!, _activeMeta));
    } else if (isInserting) {
      context.missing(_activeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {mediaItemId, tagId};
  @override
  MediaTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaTag(
      mediaItemId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}media_item_id'])!,
      tagId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}tag_id'])!,
      active: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}active'])!,
    );
  }

  @override
  $MediaTagsTable createAlias(String alias) {
    return $MediaTagsTable(attachedDatabase, alias);
  }
}

class MediaTag extends DataClass implements Insertable<MediaTag> {
  final int mediaItemId;
  final int tagId;
  final bool active;
  const MediaTag(
      {required this.mediaItemId, required this.tagId, this.active = true});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['media_item_id'] = Variable<int>(mediaItemId);
    map['tag_id'] = Variable<int>(tagId);
    if (!nullToAbsent || !active) {
      map['active'] = Variable<bool>(active);
    }
    return map;
  }

  MediaTagsCompanion toCompanion(bool nullToAbsent) {
    return MediaTagsCompanion(
      mediaItemId: Value(mediaItemId),
      tagId: Value(tagId),
      active: Value(active),
    );
  }

  factory MediaTag.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaTag(
      mediaItemId: serializer.fromJson<int>(json['mediaItemId']),
      tagId: serializer.fromJson<int>(json['tagId']),
      active: serializer.fromJson<bool>(json['active']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'mediaItemId': serializer.toJson<int>(mediaItemId),
      'tagId': serializer.toJson<int>(tagId),
      'active': serializer.toJson<bool>(active),
    };
  }

  MediaTag copyWith({int? mediaItemId, int? tagId, bool? active}) =>
      MediaTag(
        mediaItemId: mediaItemId ?? this.mediaItemId,
        tagId: tagId ?? this.tagId,
        active: active ?? this.active,
      );
  MediaTag copyWithCompanion(MediaTagsCompanion data) {
    return MediaTag(
      mediaItemId:
          data.mediaItemId.present ? data.mediaItemId.value : this.mediaItemId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
      active: data.active.present ? data.active.value : this.active,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaTag(')
          ..write('mediaItemId: $mediaItemId, ')
          ..write('tagId: $tagId, ')
          ..write('active: $active')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(mediaItemId, tagId, active);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaTag &&
          other.mediaItemId == this.mediaItemId &&
          other.tagId == this.tagId &&
          other.active == this.active);
}

class MediaTagsCompanion extends UpdateCompanion<MediaTag> {
  final Value<int> mediaItemId;
  final Value<int> tagId;
  final Value<bool> active;
  final Value<int> rowid;
  const MediaTagsCompanion({
    this.mediaItemId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.active = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MediaTagsCompanion.insert({
    required int mediaItemId,
    required int tagId,
    bool active = true,
    this.rowid = const Value.absent(),
  })  : mediaItemId = Value(mediaItemId),
        tagId = Value(tagId),
        active = Value(active);
  static Insertable<MediaTag> custom({
    Expression<int>? mediaItemId,
    Expression<int>? tagId,
    Expression<bool>? active,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (mediaItemId != null) 'media_item_id': mediaItemId,
      if (tagId != null) 'tag_id': tagId,
      if (active != null) 'active': active,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MediaTagsCompanion copyWith(
      {Value<int>? mediaItemId,
      Value<int>? tagId,
      Value<bool>? active,
      Value<int>? rowid}) {
    return MediaTagsCompanion(
      mediaItemId: mediaItemId ?? this.mediaItemId,
      tagId: tagId ?? this.tagId,
      active: active ?? this.active,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (mediaItemId.present) {
      map['media_item_id'] = Variable<int>(mediaItemId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<int>(tagId.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaTagsCompanion(')
          ..write('mediaItemId: $mediaItemId, ')
          ..write('tagId: $tagId, ')
          ..write('active: $active, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FolderScansTable extends FolderScans
    with TableInfo<$FolderScansTable, FolderScan> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FolderScansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _folderPathMeta =
      const VerificationMeta('folderPath');
  @override
  late final GeneratedColumn<String> folderPath = GeneratedColumn<String>(
      'folder_path', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _lastScannedAtMeta =
      const VerificationMeta('lastScannedAt');
  @override
  late final GeneratedColumn<DateTime> lastScannedAt =
      GeneratedColumn<DateTime>('last_scanned_at', aliasedName, false,
          type: DriftSqlType.dateTime,
          requiredDuringInsert: false,
          defaultValue: currentDateAndTime);
  static const VerificationMeta _itemCountMeta =
      const VerificationMeta('itemCount');
  @override
  late final GeneratedColumn<int> itemCount = GeneratedColumn<int>(
      'item_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _missingCountMeta =
      const VerificationMeta('missingCount');
  @override
  late final GeneratedColumn<int> missingCount = GeneratedColumn<int>(
      'missing_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns =>
      [id, folderPath, lastScannedAt, itemCount, missingCount];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'folder_scans';
  @override
  VerificationContext validateIntegrity(Insertable<FolderScan> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('folder_path')) {
      context.handle(
          _folderPathMeta,
          folderPath.isAcceptableOrUnknown(
              data['folder_path']!, _folderPathMeta));
    } else if (isInserting) {
      context.missing(_folderPathMeta);
    }
    if (data.containsKey('last_scanned_at')) {
      context.handle(
          _lastScannedAtMeta,
          lastScannedAt.isAcceptableOrUnknown(
              data['last_scanned_at']!, _lastScannedAtMeta));
    }
    if (data.containsKey('item_count')) {
      context.handle(_itemCountMeta,
          itemCount.isAcceptableOrUnknown(data['item_count']!, _itemCountMeta));
    }
    if (data.containsKey('missing_count')) {
      context.handle(
          _missingCountMeta,
          missingCount.isAcceptableOrUnknown(
              data['missing_count']!, _missingCountMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FolderScan map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FolderScan(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      folderPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}folder_path'])!,
      lastScannedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_scanned_at'])!,
      itemCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}item_count'])!,
      missingCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}missing_count'])!,
    );
  }

  @override
  $FolderScansTable createAlias(String alias) {
    return $FolderScansTable(attachedDatabase, alias);
  }
}

class FolderScan extends DataClass implements Insertable<FolderScan> {
  final int id;
  final String folderPath;
  final DateTime lastScannedAt;
  final int itemCount;
  final int missingCount;
  const FolderScan(
      {required this.id,
      required this.folderPath,
      required this.lastScannedAt,
      required this.itemCount,
      required this.missingCount});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['folder_path'] = Variable<String>(folderPath);
    map['last_scanned_at'] = Variable<DateTime>(lastScannedAt);
    map['item_count'] = Variable<int>(itemCount);
    map['missing_count'] = Variable<int>(missingCount);
    return map;
  }

  FolderScansCompanion toCompanion(bool nullToAbsent) {
    return FolderScansCompanion(
      id: Value(id),
      folderPath: Value(folderPath),
      lastScannedAt: Value(lastScannedAt),
      itemCount: Value(itemCount),
      missingCount: Value(missingCount),
    );
  }

  factory FolderScan.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FolderScan(
      id: serializer.fromJson<int>(json['id']),
      folderPath: serializer.fromJson<String>(json['folderPath']),
      lastScannedAt: serializer.fromJson<DateTime>(json['lastScannedAt']),
      itemCount: serializer.fromJson<int>(json['itemCount']),
      missingCount: serializer.fromJson<int>(json['missingCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'folderPath': serializer.toJson<String>(folderPath),
      'lastScannedAt': serializer.toJson<DateTime>(lastScannedAt),
      'itemCount': serializer.toJson<int>(itemCount),
      'missingCount': serializer.toJson<int>(missingCount),
    };
  }

  FolderScan copyWith(
          {int? id,
          String? folderPath,
          DateTime? lastScannedAt,
          int? itemCount,
          int? missingCount}) =>
      FolderScan(
        id: id ?? this.id,
        folderPath: folderPath ?? this.folderPath,
        lastScannedAt: lastScannedAt ?? this.lastScannedAt,
        itemCount: itemCount ?? this.itemCount,
        missingCount: missingCount ?? this.missingCount,
      );
  FolderScan copyWithCompanion(FolderScansCompanion data) {
    return FolderScan(
      id: data.id.present ? data.id.value : this.id,
      folderPath:
          data.folderPath.present ? data.folderPath.value : this.folderPath,
      lastScannedAt: data.lastScannedAt.present
          ? data.lastScannedAt.value
          : this.lastScannedAt,
      itemCount: data.itemCount.present ? data.itemCount.value : this.itemCount,
      missingCount: data.missingCount.present
          ? data.missingCount.value
          : this.missingCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FolderScan(')
          ..write('id: $id, ')
          ..write('folderPath: $folderPath, ')
          ..write('lastScannedAt: $lastScannedAt, ')
          ..write('itemCount: $itemCount, ')
          ..write('missingCount: $missingCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, folderPath, lastScannedAt, itemCount, missingCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FolderScan &&
          other.id == this.id &&
          other.folderPath == this.folderPath &&
          other.lastScannedAt == this.lastScannedAt &&
          other.itemCount == this.itemCount &&
          other.missingCount == this.missingCount);
}

class FolderScansCompanion extends UpdateCompanion<FolderScan> {
  final Value<int> id;
  final Value<String> folderPath;
  final Value<DateTime> lastScannedAt;
  final Value<int> itemCount;
  final Value<int> missingCount;
  const FolderScansCompanion({
    this.id = const Value.absent(),
    this.folderPath = const Value.absent(),
    this.lastScannedAt = const Value.absent(),
    this.itemCount = const Value.absent(),
    this.missingCount = const Value.absent(),
  });
  FolderScansCompanion.insert({
    this.id = const Value.absent(),
    required String folderPath,
    this.lastScannedAt = const Value.absent(),
    this.itemCount = const Value.absent(),
    this.missingCount = const Value.absent(),
  }) : folderPath = Value(folderPath);
  static Insertable<FolderScan> custom({
    Expression<int>? id,
    Expression<String>? folderPath,
    Expression<DateTime>? lastScannedAt,
    Expression<int>? itemCount,
    Expression<int>? missingCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (folderPath != null) 'folder_path': folderPath,
      if (lastScannedAt != null) 'last_scanned_at': lastScannedAt,
      if (itemCount != null) 'item_count': itemCount,
      if (missingCount != null) 'missing_count': missingCount,
    });
  }

  FolderScansCompanion copyWith(
      {Value<int>? id,
      Value<String>? folderPath,
      Value<DateTime>? lastScannedAt,
      Value<int>? itemCount,
      Value<int>? missingCount}) {
    return FolderScansCompanion(
      id: id ?? this.id,
      folderPath: folderPath ?? this.folderPath,
      lastScannedAt: lastScannedAt ?? this.lastScannedAt,
      itemCount: itemCount ?? this.itemCount,
      missingCount: missingCount ?? this.missingCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (folderPath.present) {
      map['folder_path'] = Variable<String>(folderPath.value);
    }
    if (lastScannedAt.present) {
      map['last_scanned_at'] = Variable<DateTime>(lastScannedAt.value);
    }
    if (itemCount.present) {
      map['item_count'] = Variable<int>(itemCount.value);
    }
    if (missingCount.present) {
      map['missing_count'] = Variable<int>(missingCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FolderScansCompanion(')
          ..write('id: $id, ')
          ..write('folderPath: $folderPath, ')
          ..write('lastScannedAt: $lastScannedAt, ')
          ..write('itemCount: $itemCount, ')
          ..write('missingCount: $missingCount')
          ..write(')'))
        .toString();
  }
}

class $MediaDateIndexesTable extends MediaDateIndexes
    with TableInfo<$MediaDateIndexesTable, MediaDateIndex> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaDateIndexesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _dateKeyMeta =
      const VerificationMeta('dateKey');
  @override
  late final GeneratedColumn<String> dateKey = GeneratedColumn<String>(
      'date_key', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'));
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<int> count = GeneratedColumn<int>(
      'count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _firstOffsetMeta =
      const VerificationMeta('firstOffset');
  @override
  late final GeneratedColumn<int> firstOffset = GeneratedColumn<int>(
      'first_offset', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, dateKey, count, firstOffset, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_date_indexes';
  @override
  VerificationContext validateIntegrity(Insertable<MediaDateIndex> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date_key')) {
      context.handle(_dateKeyMeta,
          dateKey.isAcceptableOrUnknown(data['date_key']!, _dateKeyMeta));
    } else if (isInserting) {
      context.missing(_dateKeyMeta);
    }
    if (data.containsKey('count')) {
      context.handle(
          _countMeta, count.isAcceptableOrUnknown(data['count']!, _countMeta));
    }
    if (data.containsKey('first_offset')) {
      context.handle(
          _firstOffsetMeta,
          firstOffset.isAcceptableOrUnknown(
              data['first_offset']!, _firstOffsetMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MediaDateIndex map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaDateIndex(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      dateKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}date_key'])!,
      count: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}count'])!,
      firstOffset: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}first_offset'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $MediaDateIndexesTable createAlias(String alias) {
    return $MediaDateIndexesTable(attachedDatabase, alias);
  }
}

class MediaDateIndex extends DataClass implements Insertable<MediaDateIndex> {
  final int id;
  final String dateKey;
  final int count;
  final int firstOffset;
  final DateTime updatedAt;
  const MediaDateIndex(
      {required this.id,
      required this.dateKey,
      required this.count,
      required this.firstOffset,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date_key'] = Variable<String>(dateKey);
    map['count'] = Variable<int>(count);
    map['first_offset'] = Variable<int>(firstOffset);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MediaDateIndexesCompanion toCompanion(bool nullToAbsent) {
    return MediaDateIndexesCompanion(
      id: Value(id),
      dateKey: Value(dateKey),
      count: Value(count),
      firstOffset: Value(firstOffset),
      updatedAt: Value(updatedAt),
    );
  }

  factory MediaDateIndex.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaDateIndex(
      id: serializer.fromJson<int>(json['id']),
      dateKey: serializer.fromJson<String>(json['dateKey']),
      count: serializer.fromJson<int>(json['count']),
      firstOffset: serializer.fromJson<int>(json['firstOffset']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'dateKey': serializer.toJson<String>(dateKey),
      'count': serializer.toJson<int>(count),
      'firstOffset': serializer.toJson<int>(firstOffset),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  MediaDateIndex copyWith(
          {int? id,
          String? dateKey,
          int? count,
          int? firstOffset,
          DateTime? updatedAt}) =>
      MediaDateIndex(
        id: id ?? this.id,
        dateKey: dateKey ?? this.dateKey,
        count: count ?? this.count,
        firstOffset: firstOffset ?? this.firstOffset,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  MediaDateIndex copyWithCompanion(MediaDateIndexesCompanion data) {
    return MediaDateIndex(
      id: data.id.present ? data.id.value : this.id,
      dateKey: data.dateKey.present ? data.dateKey.value : this.dateKey,
      count: data.count.present ? data.count.value : this.count,
      firstOffset:
          data.firstOffset.present ? data.firstOffset.value : this.firstOffset,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaDateIndex(')
          ..write('id: $id, ')
          ..write('dateKey: $dateKey, ')
          ..write('count: $count, ')
          ..write('firstOffset: $firstOffset, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, dateKey, count, firstOffset, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaDateIndex &&
          other.id == this.id &&
          other.dateKey == this.dateKey &&
          other.count == this.count &&
          other.firstOffset == this.firstOffset &&
          other.updatedAt == this.updatedAt);
}

class MediaDateIndexesCompanion extends UpdateCompanion<MediaDateIndex> {
  final Value<int> id;
  final Value<String> dateKey;
  final Value<int> count;
  final Value<int> firstOffset;
  final Value<DateTime> updatedAt;
  const MediaDateIndexesCompanion({
    this.id = const Value.absent(),
    this.dateKey = const Value.absent(),
    this.count = const Value.absent(),
    this.firstOffset = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  MediaDateIndexesCompanion.insert({
    this.id = const Value.absent(),
    required String dateKey,
    this.count = const Value.absent(),
    this.firstOffset = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : dateKey = Value(dateKey);
  static Insertable<MediaDateIndex> custom({
    Expression<int>? id,
    Expression<String>? dateKey,
    Expression<int>? count,
    Expression<int>? firstOffset,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dateKey != null) 'date_key': dateKey,
      if (count != null) 'count': count,
      if (firstOffset != null) 'first_offset': firstOffset,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  MediaDateIndexesCompanion copyWith(
      {Value<int>? id,
      Value<String>? dateKey,
      Value<int>? count,
      Value<int>? firstOffset,
      Value<DateTime>? updatedAt}) {
    return MediaDateIndexesCompanion(
      id: id ?? this.id,
      dateKey: dateKey ?? this.dateKey,
      count: count ?? this.count,
      firstOffset: firstOffset ?? this.firstOffset,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (dateKey.present) {
      map['date_key'] = Variable<String>(dateKey.value);
    }
    if (count.present) {
      map['count'] = Variable<int>(count.value);
    }
    if (firstOffset.present) {
      map['first_offset'] = Variable<int>(firstOffset.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaDateIndexesCompanion(')
          ..write('id: $id, ')
          ..write('dateKey: $dateKey, ')
          ..write('count: $count, ')
          ..write('firstOffset: $firstOffset, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MediaItemsTable mediaItems = $MediaItemsTable(this);
  late final $ExifDatasTable exifDatas = $ExifDatasTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $MediaTagsTable mediaTags = $MediaTagsTable(this);
  late final $FolderScansTable folderScans = $FolderScansTable(this);
  late final $MediaDateIndexesTable mediaDateIndexes =
      $MediaDateIndexesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [mediaItems, exifDatas, tags, mediaTags, folderScans, mediaDateIndexes];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('media_items',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('exif_datas', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('media_items',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('media_tags', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('tags',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('media_tags', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $$MediaItemsTableCreateCompanionBuilder = MediaItemsCompanion Function({
  Value<int> id,
  required String filePath,
  required String fileName,
  required String fileType,
  Value<String?> mimeType,
  Value<int?> fileSizeBytes,
  Value<DateTime?> fileModifiedAt,
  Value<DateTime> indexedAt,
  Value<String?> thumbnailPath,
  Value<String?> md5,
  Value<bool> isDeleted,
  Value<bool> isMissing,
});
typedef $$MediaItemsTableUpdateCompanionBuilder = MediaItemsCompanion Function({
  Value<int> id,
  Value<String> filePath,
  Value<String> fileName,
  Value<String> fileType,
  Value<String?> mimeType,
  Value<int?> fileSizeBytes,
  Value<DateTime?> fileModifiedAt,
  Value<DateTime> indexedAt,
  Value<String?> thumbnailPath,
  Value<String?> md5,
  Value<bool> isDeleted,
  Value<bool> isMissing,
});

final class $$MediaItemsTableReferences
    extends BaseReferences<_$AppDatabase, $MediaItemsTable, MediaItem> {
  $$MediaItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ExifDatasTable, List<ExifData>>
      _exifDatasRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.exifDatas,
          aliasName:
              $_aliasNameGenerator(db.mediaItems.id, db.exifDatas.mediaItemId));

  $$ExifDatasTableProcessedTableManager get exifDatasRefs {
    final manager = $$ExifDatasTableTableManager($_db, $_db.exifDatas)
        .filter((f) => f.mediaItemId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_exifDatasRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$MediaTagsTable, List<MediaTag>>
      _mediaTagsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.mediaTags,
          aliasName:
              $_aliasNameGenerator(db.mediaItems.id, db.mediaTags.mediaItemId));

  $$MediaTagsTableProcessedTableManager get mediaTagsRefs {
    final manager = $$MediaTagsTableTableManager($_db, $_db.mediaTags)
        .filter((f) => f.mediaItemId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_mediaTagsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$MediaItemsTableFilterComposer
    extends Composer<_$AppDatabase, $MediaItemsTable> {
  $$MediaItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fileName => $composableBuilder(
      column: $table.fileName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fileType => $composableBuilder(
      column: $table.fileType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mimeType => $composableBuilder(
      column: $table.mimeType, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get fileSizeBytes => $composableBuilder(
      column: $table.fileSizeBytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get fileModifiedAt => $composableBuilder(
      column: $table.fileModifiedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get indexedAt => $composableBuilder(
      column: $table.indexedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get thumbnailPath => $composableBuilder(
      column: $table.thumbnailPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get md5 => $composableBuilder(
      column: $table.md5, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isMissing => $composableBuilder(
      column: $table.isMissing, builder: (column) => ColumnFilters(column));

  Expression<bool> exifDatasRefs(
      Expression<bool> Function($$ExifDatasTableFilterComposer f) f) {
    final $$ExifDatasTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.exifDatas,
        getReferencedColumn: (t) => t.mediaItemId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ExifDatasTableFilterComposer(
              $db: $db,
              $table: $db.exifDatas,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> mediaTagsRefs(
      Expression<bool> Function($$MediaTagsTableFilterComposer f) f) {
    final $$MediaTagsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.mediaTags,
        getReferencedColumn: (t) => t.mediaItemId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MediaTagsTableFilterComposer(
              $db: $db,
              $table: $db.mediaTags,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$MediaItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $MediaItemsTable> {
  $$MediaItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fileName => $composableBuilder(
      column: $table.fileName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fileType => $composableBuilder(
      column: $table.fileType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mimeType => $composableBuilder(
      column: $table.mimeType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get fileSizeBytes => $composableBuilder(
      column: $table.fileSizeBytes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get fileModifiedAt => $composableBuilder(
      column: $table.fileModifiedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get indexedAt => $composableBuilder(
      column: $table.indexedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get thumbnailPath => $composableBuilder(
      column: $table.thumbnailPath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get md5 => $composableBuilder(
      column: $table.md5, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isMissing => $composableBuilder(
      column: $table.isMissing, builder: (column) => ColumnOrderings(column));
}

class $$MediaItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MediaItemsTable> {
  $$MediaItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get fileType =>
      $composableBuilder(column: $table.fileType, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<int> get fileSizeBytes => $composableBuilder(
      column: $table.fileSizeBytes, builder: (column) => column);

  GeneratedColumn<DateTime> get fileModifiedAt => $composableBuilder(
      column: $table.fileModifiedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get indexedAt =>
      $composableBuilder(column: $table.indexedAt, builder: (column) => column);

  GeneratedColumn<String> get thumbnailPath => $composableBuilder(
      column: $table.thumbnailPath, builder: (column) => column);

  GeneratedColumn<String> get md5 =>
      $composableBuilder(column: $table.md5, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<bool> get isMissing =>
      $composableBuilder(column: $table.isMissing, builder: (column) => column);

  Expression<T> exifDatasRefs<T extends Object>(
      Expression<T> Function($$ExifDatasTableAnnotationComposer a) f) {
    final $$ExifDatasTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.exifDatas,
        getReferencedColumn: (t) => t.mediaItemId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ExifDatasTableAnnotationComposer(
              $db: $db,
              $table: $db.exifDatas,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> mediaTagsRefs<T extends Object>(
      Expression<T> Function($$MediaTagsTableAnnotationComposer a) f) {
    final $$MediaTagsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.mediaTags,
        getReferencedColumn: (t) => t.mediaItemId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MediaTagsTableAnnotationComposer(
              $db: $db,
              $table: $db.mediaTags,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$MediaItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MediaItemsTable,
    MediaItem,
    $$MediaItemsTableFilterComposer,
    $$MediaItemsTableOrderingComposer,
    $$MediaItemsTableAnnotationComposer,
    $$MediaItemsTableCreateCompanionBuilder,
    $$MediaItemsTableUpdateCompanionBuilder,
    (MediaItem, $$MediaItemsTableReferences),
    MediaItem,
    PrefetchHooks Function({bool exifDatasRefs, bool mediaTagsRefs})> {
  $$MediaItemsTableTableManager(_$AppDatabase db, $MediaItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MediaItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> filePath = const Value.absent(),
            Value<String> fileName = const Value.absent(),
            Value<String> fileType = const Value.absent(),
            Value<String?> mimeType = const Value.absent(),
            Value<int?> fileSizeBytes = const Value.absent(),
            Value<DateTime?> fileModifiedAt = const Value.absent(),
            Value<DateTime> indexedAt = const Value.absent(),
            Value<String?> thumbnailPath = const Value.absent(),
            Value<String?> md5 = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<bool> isMissing = const Value.absent(),
          }) =>
              MediaItemsCompanion(
            id: id,
            filePath: filePath,
            fileName: fileName,
            fileType: fileType,
            mimeType: mimeType,
            fileSizeBytes: fileSizeBytes,
            fileModifiedAt: fileModifiedAt,
            indexedAt: indexedAt,
            thumbnailPath: thumbnailPath,
            md5: md5,
            isDeleted: isDeleted,
            isMissing: isMissing,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String filePath,
            required String fileName,
            required String fileType,
            Value<String?> mimeType = const Value.absent(),
            Value<int?> fileSizeBytes = const Value.absent(),
            Value<DateTime?> fileModifiedAt = const Value.absent(),
            Value<DateTime> indexedAt = const Value.absent(),
            Value<String?> thumbnailPath = const Value.absent(),
            Value<String?> md5 = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<bool> isMissing = const Value.absent(),
          }) =>
              MediaItemsCompanion.insert(
            id: id,
            filePath: filePath,
            fileName: fileName,
            fileType: fileType,
            mimeType: mimeType,
            fileSizeBytes: fileSizeBytes,
            fileModifiedAt: fileModifiedAt,
            indexedAt: indexedAt,
            thumbnailPath: thumbnailPath,
            md5: md5,
            isDeleted: isDeleted,
            isMissing: isMissing,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$MediaItemsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {exifDatasRefs = false, mediaTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (exifDatasRefs) db.exifDatas,
                if (mediaTagsRefs) db.mediaTags
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (exifDatasRefs)
                    await $_getPrefetchedData<MediaItem, $MediaItemsTable,
                            ExifData>(
                        currentTable: table,
                        referencedTable:
                            $$MediaItemsTableReferences._exifDatasRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$MediaItemsTableReferences(db, table, p0)
                                .exifDatasRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.mediaItemId == item.id),
                        typedResults: items),
                  if (mediaTagsRefs)
                    await $_getPrefetchedData<MediaItem, $MediaItemsTable,
                            MediaTag>(
                        currentTable: table,
                        referencedTable:
                            $$MediaItemsTableReferences._mediaTagsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$MediaItemsTableReferences(db, table, p0)
                                .mediaTagsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.mediaItemId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$MediaItemsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MediaItemsTable,
    MediaItem,
    $$MediaItemsTableFilterComposer,
    $$MediaItemsTableOrderingComposer,
    $$MediaItemsTableAnnotationComposer,
    $$MediaItemsTableCreateCompanionBuilder,
    $$MediaItemsTableUpdateCompanionBuilder,
    (MediaItem, $$MediaItemsTableReferences),
    MediaItem,
    PrefetchHooks Function({bool exifDatasRefs, bool mediaTagsRefs})>;
typedef $$ExifDatasTableCreateCompanionBuilder = ExifDatasCompanion Function({
  Value<int> id,
  required int mediaItemId,
  Value<String?> make,
  Value<String?> model,
  Value<String?> software,
  Value<DateTime?> dateTaken,
  Value<double?> latitude,
  Value<double?> longitude,
  Value<String?> cityName,
  Value<String?> province,
  Value<String?> district,
  Value<String?> isoSpeed,
  Value<String?> fNumber,
  Value<String?> exposureTime,
  Value<String?> focalLength,
  Value<int?> imageWidth,
  Value<int?> imageHeight,
  Value<String?> orientation,
  Value<String?> rawJson,
});
typedef $$ExifDatasTableUpdateCompanionBuilder = ExifDatasCompanion Function({
  Value<int> id,
  Value<int> mediaItemId,
  Value<String?> make,
  Value<String?> model,
  Value<String?> software,
  Value<DateTime?> dateTaken,
  Value<double?> latitude,
  Value<double?> longitude,
  Value<String?> cityName,
  Value<String?> province,
  Value<String?> district,
  Value<String?> isoSpeed,
  Value<String?> fNumber,
  Value<String?> exposureTime,
  Value<String?> focalLength,
  Value<int?> imageWidth,
  Value<int?> imageHeight,
  Value<String?> orientation,
  Value<String?> rawJson,
});

final class $$ExifDatasTableReferences
    extends BaseReferences<_$AppDatabase, $ExifDatasTable, ExifData> {
  $$ExifDatasTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MediaItemsTable _mediaItemIdTable(_$AppDatabase db) =>
      db.mediaItems.createAlias(
          $_aliasNameGenerator(db.exifDatas.mediaItemId, db.mediaItems.id));

  $$MediaItemsTableProcessedTableManager get mediaItemId {
    final $_column = $_itemColumn<int>('media_item_id')!;

    final manager = $$MediaItemsTableTableManager($_db, $_db.mediaItems)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mediaItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ExifDatasTableFilterComposer
    extends Composer<_$AppDatabase, $ExifDatasTable> {
  $$ExifDatasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get make => $composableBuilder(
      column: $table.make, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get model => $composableBuilder(
      column: $table.model, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get software => $composableBuilder(
      column: $table.software, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get dateTaken => $composableBuilder(
      column: $table.dateTaken, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cityName => $composableBuilder(
      column: $table.cityName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get province => $composableBuilder(
      column: $table.province, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get district => $composableBuilder(
      column: $table.district, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get isoSpeed => $composableBuilder(
      column: $table.isoSpeed, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fNumber => $composableBuilder(
      column: $table.fNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get exposureTime => $composableBuilder(
      column: $table.exposureTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get focalLength => $composableBuilder(
      column: $table.focalLength, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get imageWidth => $composableBuilder(
      column: $table.imageWidth, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get imageHeight => $composableBuilder(
      column: $table.imageHeight, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get orientation => $composableBuilder(
      column: $table.orientation, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rawJson => $composableBuilder(
      column: $table.rawJson, builder: (column) => ColumnFilters(column));

  $$MediaItemsTableFilterComposer get mediaItemId {
    final $$MediaItemsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.mediaItemId,
        referencedTable: $db.mediaItems,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MediaItemsTableFilterComposer(
              $db: $db,
              $table: $db.mediaItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ExifDatasTableOrderingComposer
    extends Composer<_$AppDatabase, $ExifDatasTable> {
  $$ExifDatasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get make => $composableBuilder(
      column: $table.make, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get model => $composableBuilder(
      column: $table.model, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get software => $composableBuilder(
      column: $table.software, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get dateTaken => $composableBuilder(
      column: $table.dateTaken, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get latitude => $composableBuilder(
      column: $table.latitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get longitude => $composableBuilder(
      column: $table.longitude, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cityName => $composableBuilder(
      column: $table.cityName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get province => $composableBuilder(
      column: $table.province, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get district => $composableBuilder(
      column: $table.district, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get isoSpeed => $composableBuilder(
      column: $table.isoSpeed, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fNumber => $composableBuilder(
      column: $table.fNumber, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get exposureTime => $composableBuilder(
      column: $table.exposureTime,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get focalLength => $composableBuilder(
      column: $table.focalLength, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get imageWidth => $composableBuilder(
      column: $table.imageWidth, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get imageHeight => $composableBuilder(
      column: $table.imageHeight, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get orientation => $composableBuilder(
      column: $table.orientation, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rawJson => $composableBuilder(
      column: $table.rawJson, builder: (column) => ColumnOrderings(column));

  $$MediaItemsTableOrderingComposer get mediaItemId {
    final $$MediaItemsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.mediaItemId,
        referencedTable: $db.mediaItems,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MediaItemsTableOrderingComposer(
              $db: $db,
              $table: $db.mediaItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ExifDatasTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExifDatasTable> {
  $$ExifDatasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get make =>
      $composableBuilder(column: $table.make, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get software =>
      $composableBuilder(column: $table.software, builder: (column) => column);

  GeneratedColumn<DateTime> get dateTaken =>
      $composableBuilder(column: $table.dateTaken, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<String> get cityName =>
      $composableBuilder(column: $table.cityName, builder: (column) => column);

  GeneratedColumn<String> get province =>
      $composableBuilder(column: $table.province, builder: (column) => column);

  GeneratedColumn<String> get district =>
      $composableBuilder(column: $table.district, builder: (column) => column);

  GeneratedColumn<String> get isoSpeed =>
      $composableBuilder(column: $table.isoSpeed, builder: (column) => column);

  GeneratedColumn<String> get fNumber =>
      $composableBuilder(column: $table.fNumber, builder: (column) => column);

  GeneratedColumn<String> get exposureTime => $composableBuilder(
      column: $table.exposureTime, builder: (column) => column);

  GeneratedColumn<String> get focalLength => $composableBuilder(
      column: $table.focalLength, builder: (column) => column);

  GeneratedColumn<int> get imageWidth => $composableBuilder(
      column: $table.imageWidth, builder: (column) => column);

  GeneratedColumn<int> get imageHeight => $composableBuilder(
      column: $table.imageHeight, builder: (column) => column);

  GeneratedColumn<String> get orientation => $composableBuilder(
      column: $table.orientation, builder: (column) => column);

  GeneratedColumn<String> get rawJson =>
      $composableBuilder(column: $table.rawJson, builder: (column) => column);

  $$MediaItemsTableAnnotationComposer get mediaItemId {
    final $$MediaItemsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.mediaItemId,
        referencedTable: $db.mediaItems,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MediaItemsTableAnnotationComposer(
              $db: $db,
              $table: $db.mediaItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ExifDatasTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ExifDatasTable,
    ExifData,
    $$ExifDatasTableFilterComposer,
    $$ExifDatasTableOrderingComposer,
    $$ExifDatasTableAnnotationComposer,
    $$ExifDatasTableCreateCompanionBuilder,
    $$ExifDatasTableUpdateCompanionBuilder,
    (ExifData, $$ExifDatasTableReferences),
    ExifData,
    PrefetchHooks Function({bool mediaItemId})> {
  $$ExifDatasTableTableManager(_$AppDatabase db, $ExifDatasTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExifDatasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExifDatasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExifDatasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> mediaItemId = const Value.absent(),
            Value<String?> make = const Value.absent(),
            Value<String?> model = const Value.absent(),
            Value<String?> software = const Value.absent(),
            Value<DateTime?> dateTaken = const Value.absent(),
            Value<double?> latitude = const Value.absent(),
            Value<double?> longitude = const Value.absent(),
            Value<String?> cityName = const Value.absent(),
            Value<String?> province = const Value.absent(),
            Value<String?> district = const Value.absent(),
            Value<String?> isoSpeed = const Value.absent(),
            Value<String?> fNumber = const Value.absent(),
            Value<String?> exposureTime = const Value.absent(),
            Value<String?> focalLength = const Value.absent(),
            Value<int?> imageWidth = const Value.absent(),
            Value<int?> imageHeight = const Value.absent(),
            Value<String?> orientation = const Value.absent(),
            Value<String?> rawJson = const Value.absent(),
          }) =>
              ExifDatasCompanion(
            id: id,
            mediaItemId: mediaItemId,
            make: make,
            model: model,
            software: software,
            dateTaken: dateTaken,
            latitude: latitude,
            longitude: longitude,
            cityName: cityName,
            province: province,
            district: district,
            isoSpeed: isoSpeed,
            fNumber: fNumber,
            exposureTime: exposureTime,
            focalLength: focalLength,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
            orientation: orientation,
            rawJson: rawJson,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int mediaItemId,
            Value<String?> make = const Value.absent(),
            Value<String?> model = const Value.absent(),
            Value<String?> software = const Value.absent(),
            Value<DateTime?> dateTaken = const Value.absent(),
            Value<double?> latitude = const Value.absent(),
            Value<double?> longitude = const Value.absent(),
            Value<String?> cityName = const Value.absent(),
            Value<String?> province = const Value.absent(),
            Value<String?> district = const Value.absent(),
            Value<String?> isoSpeed = const Value.absent(),
            Value<String?> fNumber = const Value.absent(),
            Value<String?> exposureTime = const Value.absent(),
            Value<String?> focalLength = const Value.absent(),
            Value<int?> imageWidth = const Value.absent(),
            Value<int?> imageHeight = const Value.absent(),
            Value<String?> orientation = const Value.absent(),
            Value<String?> rawJson = const Value.absent(),
          }) =>
              ExifDatasCompanion.insert(
            id: id,
            mediaItemId: mediaItemId,
            make: make,
            model: model,
            software: software,
            dateTaken: dateTaken,
            latitude: latitude,
            longitude: longitude,
            cityName: cityName,
            province: province,
            district: district,
            isoSpeed: isoSpeed,
            fNumber: fNumber,
            exposureTime: exposureTime,
            focalLength: focalLength,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
            orientation: orientation,
            rawJson: rawJson,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ExifDatasTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({mediaItemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (mediaItemId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.mediaItemId,
                    referencedTable:
                        $$ExifDatasTableReferences._mediaItemIdTable(db),
                    referencedColumn:
                        $$ExifDatasTableReferences._mediaItemIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$ExifDatasTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ExifDatasTable,
    ExifData,
    $$ExifDatasTableFilterComposer,
    $$ExifDatasTableOrderingComposer,
    $$ExifDatasTableAnnotationComposer,
    $$ExifDatasTableCreateCompanionBuilder,
    $$ExifDatasTableUpdateCompanionBuilder,
    (ExifData, $$ExifDatasTableReferences),
    ExifData,
    PrefetchHooks Function({bool mediaItemId})>;
typedef $$TagsTableCreateCompanionBuilder = TagsCompanion Function({
  Value<int> id,
  required String name,
  Value<String> color,
  Value<DateTime> createdAt,
});
typedef $$TagsTableUpdateCompanionBuilder = TagsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> color,
  Value<DateTime> createdAt,
});

final class $$TagsTableReferences
    extends BaseReferences<_$AppDatabase, $TagsTable, Tag> {
  $$TagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MediaTagsTable, List<MediaTag>>
      _mediaTagsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.mediaTags,
              aliasName: $_aliasNameGenerator(db.tags.id, db.mediaTags.tagId));

  $$MediaTagsTableProcessedTableManager get mediaTagsRefs {
    final manager = $$MediaTagsTableTableManager($_db, $_db.mediaTags)
        .filter((f) => f.tagId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_mediaTagsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$TagsTableFilterComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  Expression<bool> mediaTagsRefs(
      Expression<bool> Function($$MediaTagsTableFilterComposer f) f) {
    final $$MediaTagsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.mediaTags,
        getReferencedColumn: (t) => t.tagId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MediaTagsTableFilterComposer(
              $db: $db,
              $table: $db.mediaTags,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$TagsTableOrderingComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$TagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> mediaTagsRefs<T extends Object>(
      Expression<T> Function($$MediaTagsTableAnnotationComposer a) f) {
    final $$MediaTagsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.mediaTags,
        getReferencedColumn: (t) => t.tagId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MediaTagsTableAnnotationComposer(
              $db: $db,
              $table: $db.mediaTags,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$TagsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TagsTable,
    Tag,
    $$TagsTableFilterComposer,
    $$TagsTableOrderingComposer,
    $$TagsTableAnnotationComposer,
    $$TagsTableCreateCompanionBuilder,
    $$TagsTableUpdateCompanionBuilder,
    (Tag, $$TagsTableReferences),
    Tag,
    PrefetchHooks Function({bool mediaTagsRefs})> {
  $$TagsTableTableManager(_$AppDatabase db, $TagsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> color = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              TagsCompanion(
            id: id,
            name: name,
            color: color,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            Value<String> color = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              TagsCompanion.insert(
            id: id,
            name: name,
            color: color,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$TagsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({mediaTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (mediaTagsRefs) db.mediaTags],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (mediaTagsRefs)
                    await $_getPrefetchedData<Tag, $TagsTable, MediaTag>(
                        currentTable: table,
                        referencedTable:
                            $$TagsTableReferences._mediaTagsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$TagsTableReferences(db, table, p0).mediaTagsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.tagId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$TagsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TagsTable,
    Tag,
    $$TagsTableFilterComposer,
    $$TagsTableOrderingComposer,
    $$TagsTableAnnotationComposer,
    $$TagsTableCreateCompanionBuilder,
    $$TagsTableUpdateCompanionBuilder,
    (Tag, $$TagsTableReferences),
    Tag,
    PrefetchHooks Function({bool mediaTagsRefs})>;
typedef $$MediaTagsTableCreateCompanionBuilder = MediaTagsCompanion Function({
  required int mediaItemId,
  required int tagId,
  Value<int> rowid,
});
typedef $$MediaTagsTableUpdateCompanionBuilder = MediaTagsCompanion Function({
  Value<int> mediaItemId,
  Value<int> tagId,
  Value<int> rowid,
});

final class $$MediaTagsTableReferences
    extends BaseReferences<_$AppDatabase, $MediaTagsTable, MediaTag> {
  $$MediaTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MediaItemsTable _mediaItemIdTable(_$AppDatabase db) =>
      db.mediaItems.createAlias(
          $_aliasNameGenerator(db.mediaTags.mediaItemId, db.mediaItems.id));

  $$MediaItemsTableProcessedTableManager get mediaItemId {
    final $_column = $_itemColumn<int>('media_item_id')!;

    final manager = $$MediaItemsTableTableManager($_db, $_db.mediaItems)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mediaItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $TagsTable _tagIdTable(_$AppDatabase db) =>
      db.tags.createAlias($_aliasNameGenerator(db.mediaTags.tagId, db.tags.id));

  $$TagsTableProcessedTableManager get tagId {
    final $_column = $_itemColumn<int>('tag_id')!;

    final manager = $$TagsTableTableManager($_db, $_db.tags)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$MediaTagsTableFilterComposer
    extends Composer<_$AppDatabase, $MediaTagsTable> {
  $$MediaTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$MediaItemsTableFilterComposer get mediaItemId {
    final $$MediaItemsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.mediaItemId,
        referencedTable: $db.mediaItems,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MediaItemsTableFilterComposer(
              $db: $db,
              $table: $db.mediaItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$TagsTableFilterComposer get tagId {
    final $$TagsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.tagId,
        referencedTable: $db.tags,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TagsTableFilterComposer(
              $db: $db,
              $table: $db.tags,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MediaTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $MediaTagsTable> {
  $$MediaTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$MediaItemsTableOrderingComposer get mediaItemId {
    final $$MediaItemsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.mediaItemId,
        referencedTable: $db.mediaItems,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MediaItemsTableOrderingComposer(
              $db: $db,
              $table: $db.mediaItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$TagsTableOrderingComposer get tagId {
    final $$TagsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.tagId,
        referencedTable: $db.tags,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TagsTableOrderingComposer(
              $db: $db,
              $table: $db.tags,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MediaTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MediaTagsTable> {
  $$MediaTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$MediaItemsTableAnnotationComposer get mediaItemId {
    final $$MediaItemsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.mediaItemId,
        referencedTable: $db.mediaItems,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$MediaItemsTableAnnotationComposer(
              $db: $db,
              $table: $db.mediaItems,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$TagsTableAnnotationComposer get tagId {
    final $$TagsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.tagId,
        referencedTable: $db.tags,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$TagsTableAnnotationComposer(
              $db: $db,
              $table: $db.tags,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$MediaTagsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MediaTagsTable,
    MediaTag,
    $$MediaTagsTableFilterComposer,
    $$MediaTagsTableOrderingComposer,
    $$MediaTagsTableAnnotationComposer,
    $$MediaTagsTableCreateCompanionBuilder,
    $$MediaTagsTableUpdateCompanionBuilder,
    (MediaTag, $$MediaTagsTableReferences),
    MediaTag,
    PrefetchHooks Function({bool mediaItemId, bool tagId})> {
  $$MediaTagsTableTableManager(_$AppDatabase db, $MediaTagsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MediaTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> mediaItemId = const Value.absent(),
            Value<int> tagId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MediaTagsCompanion(
            mediaItemId: mediaItemId,
            tagId: tagId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int mediaItemId,
            required int tagId,
            Value<int> rowid = const Value.absent(),
          }) =>
              MediaTagsCompanion.insert(
            mediaItemId: mediaItemId,
            tagId: tagId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$MediaTagsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({mediaItemId = false, tagId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (mediaItemId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.mediaItemId,
                    referencedTable:
                        $$MediaTagsTableReferences._mediaItemIdTable(db),
                    referencedColumn:
                        $$MediaTagsTableReferences._mediaItemIdTable(db).id,
                  ) as T;
                }
                if (tagId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.tagId,
                    referencedTable: $$MediaTagsTableReferences._tagIdTable(db),
                    referencedColumn:
                        $$MediaTagsTableReferences._tagIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$MediaTagsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MediaTagsTable,
    MediaTag,
    $$MediaTagsTableFilterComposer,
    $$MediaTagsTableOrderingComposer,
    $$MediaTagsTableAnnotationComposer,
    $$MediaTagsTableCreateCompanionBuilder,
    $$MediaTagsTableUpdateCompanionBuilder,
    (MediaTag, $$MediaTagsTableReferences),
    MediaTag,
    PrefetchHooks Function({bool mediaItemId, bool tagId})>;
typedef $$FolderScansTableCreateCompanionBuilder = FolderScansCompanion
    Function({
  Value<int> id,
  required String folderPath,
  Value<DateTime> lastScannedAt,
  Value<int> itemCount,
  Value<int> missingCount,
});
typedef $$FolderScansTableUpdateCompanionBuilder = FolderScansCompanion
    Function({
  Value<int> id,
  Value<String> folderPath,
  Value<DateTime> lastScannedAt,
  Value<int> itemCount,
  Value<int> missingCount,
});

class $$FolderScansTableFilterComposer
    extends Composer<_$AppDatabase, $FolderScansTable> {
  $$FolderScansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get folderPath => $composableBuilder(
      column: $table.folderPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastScannedAt => $composableBuilder(
      column: $table.lastScannedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get itemCount => $composableBuilder(
      column: $table.itemCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get missingCount => $composableBuilder(
      column: $table.missingCount, builder: (column) => ColumnFilters(column));
}

class $$FolderScansTableOrderingComposer
    extends Composer<_$AppDatabase, $FolderScansTable> {
  $$FolderScansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get folderPath => $composableBuilder(
      column: $table.folderPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastScannedAt => $composableBuilder(
      column: $table.lastScannedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get itemCount => $composableBuilder(
      column: $table.itemCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get missingCount => $composableBuilder(
      column: $table.missingCount,
      builder: (column) => ColumnOrderings(column));
}

class $$FolderScansTableAnnotationComposer
    extends Composer<_$AppDatabase, $FolderScansTable> {
  $$FolderScansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get folderPath => $composableBuilder(
      column: $table.folderPath, builder: (column) => column);

  GeneratedColumn<DateTime> get lastScannedAt => $composableBuilder(
      column: $table.lastScannedAt, builder: (column) => column);

  GeneratedColumn<int> get itemCount =>
      $composableBuilder(column: $table.itemCount, builder: (column) => column);

  GeneratedColumn<int> get missingCount => $composableBuilder(
      column: $table.missingCount, builder: (column) => column);
}

class $$FolderScansTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FolderScansTable,
    FolderScan,
    $$FolderScansTableFilterComposer,
    $$FolderScansTableOrderingComposer,
    $$FolderScansTableAnnotationComposer,
    $$FolderScansTableCreateCompanionBuilder,
    $$FolderScansTableUpdateCompanionBuilder,
    (FolderScan, BaseReferences<_$AppDatabase, $FolderScansTable, FolderScan>),
    FolderScan,
    PrefetchHooks Function()> {
  $$FolderScansTableTableManager(_$AppDatabase db, $FolderScansTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FolderScansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FolderScansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FolderScansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> folderPath = const Value.absent(),
            Value<DateTime> lastScannedAt = const Value.absent(),
            Value<int> itemCount = const Value.absent(),
            Value<int> missingCount = const Value.absent(),
          }) =>
              FolderScansCompanion(
            id: id,
            folderPath: folderPath,
            lastScannedAt: lastScannedAt,
            itemCount: itemCount,
            missingCount: missingCount,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String folderPath,
            Value<DateTime> lastScannedAt = const Value.absent(),
            Value<int> itemCount = const Value.absent(),
            Value<int> missingCount = const Value.absent(),
          }) =>
              FolderScansCompanion.insert(
            id: id,
            folderPath: folderPath,
            lastScannedAt: lastScannedAt,
            itemCount: itemCount,
            missingCount: missingCount,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$FolderScansTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $FolderScansTable,
    FolderScan,
    $$FolderScansTableFilterComposer,
    $$FolderScansTableOrderingComposer,
    $$FolderScansTableAnnotationComposer,
    $$FolderScansTableCreateCompanionBuilder,
    $$FolderScansTableUpdateCompanionBuilder,
    (FolderScan, BaseReferences<_$AppDatabase, $FolderScansTable, FolderScan>),
    FolderScan,
    PrefetchHooks Function()>;
typedef $$MediaDateIndexesTableCreateCompanionBuilder
    = MediaDateIndexesCompanion Function({
  Value<int> id,
  required String dateKey,
  Value<int> count,
  Value<int> firstOffset,
  Value<DateTime> updatedAt,
});
typedef $$MediaDateIndexesTableUpdateCompanionBuilder
    = MediaDateIndexesCompanion Function({
  Value<int> id,
  Value<String> dateKey,
  Value<int> count,
  Value<int> firstOffset,
  Value<DateTime> updatedAt,
});

class $$MediaDateIndexesTableFilterComposer
    extends Composer<_$AppDatabase, $MediaDateIndexesTable> {
  $$MediaDateIndexesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dateKey => $composableBuilder(
      column: $table.dateKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get count => $composableBuilder(
      column: $table.count, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get firstOffset => $composableBuilder(
      column: $table.firstOffset, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$MediaDateIndexesTableOrderingComposer
    extends Composer<_$AppDatabase, $MediaDateIndexesTable> {
  $$MediaDateIndexesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dateKey => $composableBuilder(
      column: $table.dateKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get count => $composableBuilder(
      column: $table.count, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get firstOffset => $composableBuilder(
      column: $table.firstOffset, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$MediaDateIndexesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MediaDateIndexesTable> {
  $$MediaDateIndexesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get dateKey =>
      $composableBuilder(column: $table.dateKey, builder: (column) => column);

  GeneratedColumn<int> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);

  GeneratedColumn<int> get firstOffset => $composableBuilder(
      column: $table.firstOffset, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MediaDateIndexesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MediaDateIndexesTable,
    MediaDateIndex,
    $$MediaDateIndexesTableFilterComposer,
    $$MediaDateIndexesTableOrderingComposer,
    $$MediaDateIndexesTableAnnotationComposer,
    $$MediaDateIndexesTableCreateCompanionBuilder,
    $$MediaDateIndexesTableUpdateCompanionBuilder,
    (
      MediaDateIndex,
      BaseReferences<_$AppDatabase, $MediaDateIndexesTable, MediaDateIndex>
    ),
    MediaDateIndex,
    PrefetchHooks Function()> {
  $$MediaDateIndexesTableTableManager(
      _$AppDatabase db, $MediaDateIndexesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaDateIndexesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaDateIndexesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MediaDateIndexesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> dateKey = const Value.absent(),
            Value<int> count = const Value.absent(),
            Value<int> firstOffset = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              MediaDateIndexesCompanion(
            id: id,
            dateKey: dateKey,
            count: count,
            firstOffset: firstOffset,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String dateKey,
            Value<int> count = const Value.absent(),
            Value<int> firstOffset = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              MediaDateIndexesCompanion.insert(
            id: id,
            dateKey: dateKey,
            count: count,
            firstOffset: firstOffset,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MediaDateIndexesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MediaDateIndexesTable,
    MediaDateIndex,
    $$MediaDateIndexesTableFilterComposer,
    $$MediaDateIndexesTableOrderingComposer,
    $$MediaDateIndexesTableAnnotationComposer,
    $$MediaDateIndexesTableCreateCompanionBuilder,
    $$MediaDateIndexesTableUpdateCompanionBuilder,
    (
      MediaDateIndex,
      BaseReferences<_$AppDatabase, $MediaDateIndexesTable, MediaDateIndex>
    ),
    MediaDateIndex,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MediaItemsTableTableManager get mediaItems =>
      $$MediaItemsTableTableManager(_db, _db.mediaItems);
  $$ExifDatasTableTableManager get exifDatas =>
      $$ExifDatasTableTableManager(_db, _db.exifDatas);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$MediaTagsTableTableManager get mediaTags =>
      $$MediaTagsTableTableManager(_db, _db.mediaTags);
  $$FolderScansTableTableManager get folderScans =>
      $$FolderScansTableTableManager(_db, _db.folderScans);
  $$MediaDateIndexesTableTableManager get mediaDateIndexes =>
      $$MediaDateIndexesTableTableManager(_db, _db.mediaDateIndexes);
}
