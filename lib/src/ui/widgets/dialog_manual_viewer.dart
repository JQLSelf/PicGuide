// ============================================================
// lib/src/ui/widgets/dialog_manual_viewer.dart
// 使用手册弹窗：滚动显示 Markdown 文本
// （暂不引入 flutter_markdown 依赖，使用 Text 渲染 + 自动识别标题）
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/service_manual.dart';

class ManualViewerDialog extends StatefulWidget {
  const ManualViewerDialog({super.key});

  /// 显示弹窗
  static Future<void> show(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const ManualViewerDialog(),
    );
  }

  @override
  State<ManualViewerDialog> createState() => _ManualViewerDialogState();
}

class _ManualViewerDialogState extends State<ManualViewerDialog> {
  String? _content;
  String? _error;
  bool _copyOk = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final md = await ManualService().loadContent();
      if (!mounted) return;
      setState(() => _content = md);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  void _copyAll() async {
    if (_content == null) return;
    await Clipboard.setData(ClipboardData(text: _content!));
    if (!mounted) return;
    setState(() => _copyOk = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copyOk = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 24 + mq.padding.top,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 880,
          maxHeight: mq.size.height - mq.padding.top - mq.padding.bottom - 48,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 标题栏 ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF5B8DEF), Color(0xFF7B5BEF)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.menu_book_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('使用手册',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    tooltip: _copyOk ? '已复制' : '复制全文',
                    onPressed: _copyOk ? null : _copyAll,
                    icon: Icon(
                      _copyOk ? Icons.check_circle_rounded : Icons.copy_rounded,
                      color: _copyOk ? Colors.green : null,
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // ── 内容区 ──
            Expanded(
              child: _buildBody(),
            ),
            // ── 底部状态栏 ──
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '手册同时已生成到应用安装目录下的 USER_MANUAL.md，可直接用记事本打开',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text('加载失败：$_error', style: const TextStyle(color: Colors.red)),
      );
    }
    if (_content == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return _MarkdownView(text: _content!);
  }
}

/// 极简 Markdown 渲染：识别 # 标题 / - 列表 / ` ` / 段落 / 空行
class _MarkdownView extends StatefulWidget {
  final String text;
  const _MarkdownView({required this.text});

  @override
  State<_MarkdownView> createState() => _MarkdownViewState();
}

class _MarkdownViewState extends State<_MarkdownView> {
  late ScrollController _scrollController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollByKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
    final key = event.logicalKey;
    const scrollAmount = 80.0;
    if (key == LogicalKeyboardKey.arrowUp) {
      _scrollController.animateTo(
        _scrollController.offset - scrollAmount,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _scrollController.animateTo(
        _scrollController.offset + scrollAmount,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    } else if (key == LogicalKeyboardKey.pageUp) {
      _scrollController.animateTo(
        _scrollController.offset - 400,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    } else if (key == LogicalKeyboardKey.pageDown) {
      _scrollController.animateTo(
        _scrollController.offset + 400,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    } else if (key == LogicalKeyboardKey.home) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else if (key == LogicalKeyboardKey.end) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.text.split('\n');
    final children = <Widget>[];

    for (final raw in lines) {
      final line = raw;

      // 空行
      if (line.trim().isEmpty) {
        children.add(const SizedBox(height: 6));
        continue;
      }

      // 标题
      if (line.startsWith('# ')) {
        children.add(_h(line.substring(2), 1, context));
        continue;
      }
      if (line.startsWith('## ')) {
        children.add(_h(line.substring(3), 2, context));
        continue;
      }
      if (line.startsWith('### ')) {
        children.add(_h(line.substring(4), 3, context));
        continue;
      }
      if (line.startsWith('#### ')) {
        children.add(_h(line.substring(5), 4, context));
        continue;
      }

      // 分隔线
      if (line.trim() == '---') {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Divider(color: Colors.grey.shade300, height: 1),
        ));
        continue;
      }

      // 引用
      if (line.startsWith('> ')) {
        children.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: const Color(0xFF5B8DEF).withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(
                  color: const Color(0xFF5B8DEF).withOpacity(0.6), width: 3),
            ),
          ),
          child: _inline(line.substring(2), base: const TextStyle()),
        ));
        continue;
      }

      // 列表
      if (line.startsWith('- ') || line.startsWith('* ')) {
        children.add(Padding(
          padding: const EdgeInsets.only(left: 8, top: 2, bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 7, right: 8),
                child: Icon(Icons.circle, size: 4, color: Colors.grey),
              ),
              Expanded(
                  child: _inline(line.substring(2), base: const TextStyle())),
            ],
          ),
        ));
        continue;
      }

      // 表格分隔（| --- |）→ 跳过
      if (RegExp(r'^\|\s*[-:]+').hasMatch(line.trim())) {
        continue;
      }

      // 表格行
      if (line.trim().startsWith('|') && line.trim().endsWith('|')) {
        final cells = line
            .trim()
            .substring(1, line.trim().length - 1)
            .split('|')
            .map((c) => c.trim())
            .toList();
        children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: cells
                .map((c) => Expanded(
                      flex: 1,
                      child: _inline(c,
                          base: const TextStyle(
                              fontFamily: 'monospace', fontSize: 13)),
                    ))
                .toList(),
          ),
        ));
        continue;
      }

      // 普通段落
      children.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: _inline(line, base: const TextStyle()),
      ));
    }

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _scrollByKey,
      child: Scrollbar(
        controller: _scrollController,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _h(String text, int level, BuildContext context) {
    final style = switch (level) {
      1 => const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      2 => const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      3 => const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      _ => const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    };
    return Padding(
      padding: EdgeInsets.only(top: level == 1 ? 8 : 12, bottom: 6),
      child: _inline(text, base: style),
    );
  }

  /// 内联：识别 **加粗**、`code`、链接 [text](url)
  Widget _inline(String s, {required TextStyle base}) {
    // 极简：先把 `code` 切出来作为 spans
    final spans = <InlineSpan>[];
    final regex = RegExp(r'(`[^`]+`|\*\*[^*]+\*\*|\[[^\]]+\]\([^)]+\))');
    int last = 0;
    for (final m in regex.allMatches(s)) {
      if (m.start > last) {
        spans.add(TextSpan(text: s.substring(last, m.start)));
      }
      final t = m.group(0)!;
      if (t.startsWith('`')) {
        spans.add(TextSpan(
          text: t.substring(1, t.length - 1),
          style: base.copyWith(
            fontFamily: 'monospace',
            fontSize: (base.fontSize ?? 14) - 1,
            backgroundColor: Colors.grey.shade200,
            color: const Color(0xFF7B5BEF),
          ),
        ));
      } else if (t.startsWith('**')) {
        spans.add(TextSpan(
          text: t.substring(2, t.length - 2),
          style: base.copyWith(fontWeight: FontWeight.w700),
        ));
      } else if (t.startsWith('[')) {
        // 链接简化为加粗
        final lb = t.indexOf(']');
        final txt = t.substring(1, lb);
        spans.add(TextSpan(
          text: txt,
          style: base.copyWith(
            color: const Color(0xFF5B8DEF),
            decoration: TextDecoration.underline,
          ),
        ));
      }
      last = m.end;
    }
    if (last < s.length) {
      spans.add(TextSpan(text: s.substring(last)));
    }
    return Text.rich(
      TextSpan(
          style: base.copyWith(height: 1.55, fontSize: 14), children: spans),
    );
  }
}
