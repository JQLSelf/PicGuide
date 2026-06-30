// ============================================================
// lib/src/ui/tags/dialog_tag_editor.dart
// 通用标签编辑弹窗 - 给 1 个或 N 个媒体打/去标签
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../db/database.dart';
import '../../providers/provider_app.dart';
import '../../providers/provider_database.dart';

/// 给一组媒体项编辑标签
/// - isMulti=true 时：弹"添加标签/移除标签"两个按钮
/// - isMulti=false 时：直接显示当前标签的勾选状态
///
/// 返回 `true` 表示用户点击了"保存"，`false` 表示取消或关闭。
/// 调用方应当仅在 `true` 时才触发数据刷新。
Future<bool> showTagEditorDialog(
  BuildContext context, {
  required List<MediaItem> items,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _TagEditorDialog(items: items),
  );
  return result == true;
}

class _TagEditorDialog extends ConsumerStatefulWidget {
  final List<MediaItem> items;
  const _TagEditorDialog({required this.items});

  @override
  ConsumerState<_TagEditorDialog> createState() => _TagEditorDialogState();
}

class _TagEditorDialogState extends ConsumerState<_TagEditorDialog> {
  /// 记录每个标签被勾选的目标状态
  final Map<int, bool> _pending = {};
  bool _initialized = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(allTagsProvider);
    final hasTags = tagsAsync.valueOrNull?.isNotEmpty ?? false;

    return AlertDialog(
      title: Text(
        widget.items.length == 1 ? '编辑标签' : '批量编辑标签 (${widget.items.length} 项)',
      ),
      content: SizedBox(
        width: 400,
        child: tagsAsync.when(
          loading: () => const SizedBox(
              height: 100, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Text('$e'),
          data: (tags) {
            if (tags.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(8),
                child: Text('还没有任何标签，请到「标签」页面创建'),
              );
            }
            // 首次构建：基于"当前交集"初始化 _pending
            if (!_initialized) {
              _initialized = true;
              _initPendingState(tags);
            }
            return SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags.map((t) {
                  final checked = _pending[t.id] ?? false;
                  final color =
                      _hex(t.color) ?? Theme.of(context).colorScheme.primary;
                  return FilterChip(
                    label: Text(t.name),
                    selected: checked,
                    selectedColor: color.withOpacity(0.2),
                    checkmarkColor: color,
                    side: BorderSide(color: color.withOpacity(0.5)),
                    onSelected: (v) => setState(() => _pending[t.id] = v),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: (_busy || !hasTags) ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('保存'),
        ),
      ],
    );
  }

  Future<void> _initPendingState(List<Tag> tags) async {
    if (widget.items.length == 1) {
      // 单项：以该项现有标签为准
      final current =
          await ref.read(mediaTagsProvider(widget.items.first.id).future);
      for (final t in tags) {
        _pending[t.id] = current.any((x) => x.id == t.id);
      }
    } else {
      // 多项：以"所有项共有"为准
      final sets = <Set<int>>{};
      for (final item in widget.items) {
        final ts = await ref.read(mediaTagsProvider(item.id).future);
        sets.add(ts.map((t) => t.id).toSet());
      }
      final intersection =
          sets.isEmpty ? <int>{} : sets.reduce((a, b) => a.intersection(b));
      for (final t in tags) {
        _pending[t.id] = intersection.contains(t.id);
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final db = ref.read(databaseProvider);
    final ids = widget.items.map((i) => i.id).toList();
    for (final entry in _pending.entries) {
      if (entry.value) {
        await db.addTagToManyMedia(ids, entry.key);
      } else {
        await db.removeTagFromManyMedia(ids, entry.key);
      }
    }
    // 通知所有需要刷新的 provider
    ref.invalidate(mediaTagsProvider);
    ref.invalidate(allTagsProvider);
    ref.read(browserRefreshSignalProvider.notifier).state++;
    if (mounted) Navigator.pop(context);
  }

  Color? _hex(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return null;
    }
  }
}
