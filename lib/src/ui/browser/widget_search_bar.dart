// ============================================================
// lib/src/ui/browser/widget_search_bar.dart
// 搜索栏及高级过滤组件
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../db/database.dart';
import '../../providers/provider_app.dart';
import '../../providers/provider_database.dart';
import '../tags/dialog_tag_editor.dart';
import 'page_browser.dart'
    show
        BrowserMode,
        ViewMode,
        BrowserSort,
        browserModeProvider,
        viewModeProvider,
        browserSortProvider,
        currentFolderProvider,
        currentTagFilterProvider,
        filenameSearchProvider,
        SearchFilters,
        searchFiltersProvider,
        browserMediaProvider,
        folderListProvider,
        folderTreeProvider,
        subFoldersProvider,
        browserRefreshSignalProvider,
        distinctCamerasProvider,
        distinctCitiesProvider;

/// 浏览器顶部文件名搜索框
class BrowserSearchBar extends ConsumerStatefulWidget {
  const BrowserSearchBar({super.key});

  @override
  ConsumerState<BrowserSearchBar> createState() => _BrowserSearchBarState();
}

class _BrowserSearchBarState extends ConsumerState<BrowserSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(searchFiltersProvider).filename,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(searchFiltersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasAny = !filters.isEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : Colors.white.withOpacity(0.4),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.3),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.search,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: '按文件名搜索…',
                  ),
                  onChanged: (v) {
                    ref.read(searchFiltersProvider.notifier).state =
                        filters.copyWith(filename: v);
                  },
                ),
              ),
              // 命中条数
              Consumer(
                builder: (context, ref, _) {
                  final asyncList = ref.watch(browserMediaProvider);
                  return asyncList.maybeWhen(
                    data: (items) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '${items.length}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  );
                },
              ),
              // 高级搜索按钮（带角标）
              FilterIconButton(
                badge: filters.activeExtras,
                onTap: () => _openAdvancedFilter(),
              ),
              if (hasAny)
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  tooltip: '清空全部搜索',
                  onPressed: () {
                    _controller.clear();
                    ref.read(searchFiltersProvider.notifier).state =
                        const SearchFilters();
                    setState(() {});
                  },
                ),
            ],
          ),
          // 活跃的非文件名条件 → chip 摘要行
          if (filters.activeExtras > 0) ActiveChipsRow(filters: filters),
        ],
      ),
    );
  }

  Future<void> _openAdvancedFilter() async {
    await showDialog(
      context: context,
      builder: (_) => const AdvancedFilterDialog(),
    );
  }
}

/// 带角标的过滤按钮
class FilterIconButton extends StatelessWidget {
  final int badge;
  final VoidCallback onTap;
  const FilterIconButton({super.key, required this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.tune, size: 18),
          tooltip: '高级搜索',
          onPressed: onTap,
        ),
        if (badge > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$badge',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 搜索栏下方：4 个非文件名条件的可删除 chip
class ActiveChipsRow extends ConsumerWidget {
  final SearchFilters filters;
  const ActiveChipsRow({super.key, required this.filters});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chips = <Widget>[];

    if (filters.dateRange != null) {
      final s = _fmtDate(filters.dateRange!.start);
      final e = _fmtDate(filters.dateRange!.end);
      chips.add(_chip(
        context,
        ref,
        '时间: $s ~ $e',
        onDelete: () => ref.read(searchFiltersProvider.notifier).state =
            filters.copyWith(clearDateRange: true),
      ));
    }
    if (filters.cameras.isNotEmpty) {
      chips.add(_chip(
        context,
        ref,
        '设备: ${filters.cameras.length} 项',
        onDelete: () => ref.read(searchFiltersProvider.notifier).state =
            filters.copyWith(cameras: const {}),
      ));
    }
    if (filters.cities.isNotEmpty) {
      chips.add(_chip(
        context,
        ref,
        '城市: ${filters.cities.length} 项',
        onDelete: () => ref.read(searchFiltersProvider.notifier).state =
            filters.copyWith(cities: const {}),
      ));
    }
    if (filters.tagIds.isNotEmpty) {
      chips.add(_chip(
        context,
        ref,
        '标签: ${filters.tagIds.length} 项',
        onDelete: () => ref.read(searchFiltersProvider.notifier).state =
            filters.copyWith(tagIds: const {}),
      ));
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(spacing: 6, runSpacing: 4, children: chips),
    );
  }

  Widget _chip(BuildContext context, WidgetRef ref, String label,
      {required VoidCallback onDelete}) {
    return InputChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onDeleted: onDelete,
      deleteIconColor: Theme.of(context).colorScheme.onSurfaceVariant,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}

String _fmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 自带日历按钮 + 可编辑文本的日期输入控件。
class DateField extends StatefulWidget {
  final String label;
  final DateTime? value;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime?> onChanged;

  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<DateField> {
  late final TextEditingController _controller;
  bool _internalChange = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _fmt(widget.value));
  }

  @override
  void didUpdateWidget(covariant DateField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _internalChange = true;
      _controller.text = _fmt(widget.value);
      _internalChange = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _fmt(DateTime? d) {
    if (d == null) return '';
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  DateTime? _parse(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    final m = RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})$').firstMatch(t);
    if (m == null) return null;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    return DateTime(y, mo, d);
  }

  Future<void> _pick() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.value ?? DateTime.now(),
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
    );
    if (picked != null) widget.onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: 'YYYY-MM-DD',
        isDense: true,
        suffixIcon: IconButton(
          icon: const Icon(Icons.calendar_today, size: 16),
          tooltip: '选择日期',
          onPressed: _pick,
        ),
      ),
      onChanged: (v) {
        if (_internalChange) return;
        final parsed = _parse(v);
        if (parsed != null) widget.onChanged(parsed);
      },
    );
  }
}

/// 高级搜索弹窗：设备 / 城市 / 拍摄时间 / 标签（多选）
class AdvancedFilterDialog extends ConsumerStatefulWidget {
  const AdvancedFilterDialog({super.key});

  @override
  ConsumerState<AdvancedFilterDialog> createState() =>
      _AdvancedFilterDialogState();
}

class _AdvancedFilterDialogState extends ConsumerState<AdvancedFilterDialog> {
  late SearchFilters _draft;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(searchFiltersProvider);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('高级搜索'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SectionLabel('拍摄设备（多选）'),
              MultiChips(
                future: ref.watch(distinctCamerasProvider),
                selected: _draft.cameras,
                onToggle: (v) => setState(() {
                  final next = {..._draft.cameras};
                  if (!next.add(v)) next.remove(v);
                  _draft = _draft.copyWith(cameras: next);
                }),
                emptyText: '暂无 EXIF 设备数据',
              ),
              const SizedBox(height: 14),
              SectionLabel('城市（多选）'),
              MultiChips(
                future: ref.watch(distinctCitiesProvider),
                selected: _draft.cities,
                onToggle: (v) => setState(() {
                  final next = {..._draft.cities};
                  if (!next.add(v)) next.remove(v);
                  _draft = _draft.copyWith(cities: next);
                }),
                emptyText: '暂无 EXIF 城市数据',
              ),
              const SizedBox(height: 14),
              SectionLabel('拍摄时间'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DateField(
                      label: '开始',
                      value: _draft.dateRange?.start,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
                      onChanged: (d) {
                        if (d == null) return;
                        setState(() {
                          final end = _draft.dateRange?.end;
                          _draft = _draft.copyWith(
                            dateRange: DateTimeRange(
                              start: d,
                              end: (end == null || end.isBefore(d)) ? d : end,
                            ),
                          );
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DateField(
                      label: '结束',
                      value: _draft.dateRange?.end,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(DateTime.now().year + 12, 31),
                      onChanged: (d) {
                        if (d == null) return;
                        setState(() {
                          final start = _draft.dateRange?.start;
                          _draft = _draft.copyWith(
                            dateRange: DateTimeRange(
                              start: (start == null || start.isAfter(d))
                                  ? d
                                  : start,
                              end: d,
                            ),
                          );
                        });
                      },
                    ),
                  ),
                  if (_draft.dateRange != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      tooltip: '清除时间区间',
                      onPressed: () => setState(
                          () => _draft = _draft.copyWith(clearDateRange: true)),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              SectionLabel('标签（多选，OR）'),
              TagChips(
                selected: _draft.tagIds,
                onToggle: (id) => setState(() {
                  final next = {..._draft.tagIds};
                  if (!next.add(id)) next.remove(id);
                  _draft = _draft.copyWith(tagIds: next);
                }),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() {
            _draft = _draft.copyWith(
              cameras: const {},
              cities: const {},
              tagIds: const {},
              clearDateRange: true,
            );
          }),
          child: const Text('清空'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            ref.read(searchFiltersProvider.notifier).state = _draft;
            Navigator.pop(context);
          },
          child: const Text('应用'),
        ),
      ],
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

class MultiChips extends StatelessWidget {
  final AsyncValue<List<String>> future;
  final Set<String> selected;
  final void Function(String) onToggle;
  final String emptyText;
  const MultiChips({
    super.key,
    required this.future,
    required this.selected,
    required this.onToggle,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    return future.when(
      data: (list) {
        if (list.isEmpty)
          return Text(emptyText, style: const TextStyle(fontSize: 11));
        return Wrap(
            spacing: 6,
            runSpacing: 4,
            children: list.map((s) {
              final hit = selected.contains(s);
              return ChoiceChip(
                label: Text(s, style: const TextStyle(fontSize: 11)),
                selected: hit,
                onSelected: (_) => onToggle(s),
                visualDensity: VisualDensity.compact,
              );
            }).toList());
      },
      loading: () => const Center(
          child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2))),
      error: (_, __) =>
          const Text('加载失败', style: TextStyle(color: Colors.red, fontSize: 11)),
    );
  }
}

class TagChips extends ConsumerWidget {
  final Set<int> selected;
  final ValueChanged<int> onToggle;
  const TagChips({super.key, required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(allTagsProvider);
    return tagsAsync.when(
      data: (tags) {
        if (tags.isEmpty)
          return const Text('暂无标签，请先在详情页添加', style: TextStyle(fontSize: 11));
        return Wrap(
            spacing: 6,
            runSpacing: 4,
            children: tags.map((t) {
              final hit = selected.contains(t.id);
              return ChoiceChip(
                avatar: t.colorHex != null
                    ? CircleAvatar(
                        radius: 9,
                        backgroundColor: Color(int.parse(t.colorHex!)))
                    : null,
                label: Text(t.name, style: const TextStyle(fontSize: 11)),
                selected: hit,
                onSelected: (_) => onToggle(t.id),
                visualDensity: VisualDensity.compact,
              );
            }).toList());
      },
      loading: () => const Center(
          child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2))),
      error: (_, __) =>
          const Text('加载失败', style: TextStyle(color: Colors.red, fontSize: 11)),
    );
  }
}
