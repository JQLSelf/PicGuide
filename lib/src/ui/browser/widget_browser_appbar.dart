// ============================================================
// lib/src/ui/browser/widget_browser_appbar.dart
// 胶囊 AppBar 组件
// ============================================================

import 'package:flutter/material.dart';

/// 胶囊 AppBar：圆角浮动 + 毛玻璃
class CapsuleAppBar extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final List<Widget> actions;

  const CapsuleAppBar({
    super.key,
    required this.leading,
    required this.title,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E1F2D).withOpacity(0.85)
            : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (leading != null) leading!,
          const SizedBox(width: 8),
          Expanded(
              child: DefaultTextStyle.merge(
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            child: title,
          )),
          ...actions,
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
