// ============================================================
// lib/src/providers/provider_database.dart
// 全局数据库实例 Provider
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/database.dart';

/// 全局数据库实例，在 main.dart 中通过 overrideWithValue 注入
final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('databaseProvider must be overridden in main()');
});
