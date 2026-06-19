// ============================================================
// lib/main.dart - 应用入口
// 整体风格：胶囊 + 玻璃 + 圆角 + 柔和阴影
// 支持白天/黑夜模式自适应
// ============================================================
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';
import 'src/providers/provider_app.dart';
import 'src/ui/browser/page_browser.dart';
import 'src/ui/dashboard/page_dashboard.dart';
import 'src/db/database.dart';
import 'src/providers/provider_database.dart';
import 'src/services/service_manual.dart';
import 'src/services/service_scan_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 桌面端窗口管理初始化（仅用于拦截关闭事件）
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
  }

  // ImageCache 配置：扩大 LRU 上限，减少 GC 抖动
  // 默认是 100 项 / 100 MB，对 4 列 GridView + 大量图片的浏览器来说太紧张
  final cache = PaintingBinding.instance.imageCache;
  cache.maximumSize = 300;
  cache.maximumSizeBytes = 200 << 20; // 200 MB

  final db = AppDatabase();

  // 把手册拷贝到安装目录（fire-and-forget；失败也不影响启动）
  ManualService().ensureInInstallDir();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
      child: const PixelVaultApp(),
    ),
  );
}

/// 主题模式 Provider
final themeModeProvider = StateProvider<ThemeMode>((_) => ThemeMode.system);

class PixelVaultApp extends ConsumerWidget {
  const PixelVaultApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'PixelVault',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: themeMode,
      home: const AppShell(),
    );
  }

  static ThemeData _buildLightTheme() {
    const seed = Color(0xFF5B8DEF);
    const surface = Color(0xFFF6F7FB);
    const surfaceVariant = Color(0xFFEEF1F8);
    const outline = Color(0xFFD8DDE7);

    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.light,
      ).copyWith(
        surface: surface,
        surfaceContainerHighest: surfaceVariant,
        outline: outline,
      ),
      scaffoldBackgroundColor: surface,
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
      useMaterial3: true,
      // 主题级圆角 token
      cardTheme: CardTheme(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: Colors.white.withOpacity(0.85),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogTheme(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: seed.withOpacity(0.5), width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE8ECF4),
        thickness: 1,
      ),
    );
  }

  static ThemeData _buildDarkTheme() {
    const seed = Color(0xFF6B9BFF);
    const surface = Color(0xFF12131A);
    const surfaceVariant = Color(0xFF1E1F2D);
    const outline = Color(0xFF2E3041);

    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
      ).copyWith(
        surface: surface,
        surfaceContainerHighest: surfaceVariant,
        outline: outline,
      ),
      scaffoldBackgroundColor: surface,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      useMaterial3: true,
      cardTheme: CardTheme(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: surfaceVariant.withOpacity(0.7),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogTheme(
        elevation: 0,
        backgroundColor: surfaceVariant,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: seed.withOpacity(0.5), width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2E3041),
        thickness: 1,
      ),
    );
  }
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WindowListener, SingleTickerProviderStateMixin {
  int _lastRefreshSignal = 0;
  bool _isExiting = false;
  late AnimationController _exitAnimationController;
  late Animation<double> _exitOpacity;
  late Animation<double> _exitScale;

  static const List<({IconData icon, IconData selectedIcon, String label})>
      _navItems = [
    (
      icon: Icons.photo_library_outlined,
      selectedIcon: Icons.photo_library,
      label: '浏览器',
    ),
    (
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: '仪表盘',
    ),
  ];

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.addListener(this);
    }
    _exitAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitAnimationController, curve: Curves.easeInOut),
    );
    _exitScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _exitAnimationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.removeListener(this);
    }
    _exitAnimationController.dispose();
    super.dispose();
  }

  @override
  void onWindowClose() async {
    if (_isExiting) return;

    final scanController = ref.read(scanControllerProvider);
    final isScanning = scanController != null &&
        (scanController.state == ScanState.scanning ||
            scanController.state == ScanState.paused ||
            scanController.state == ScanState.stopping);

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('退出应用'),
        content: Text(isScanning
            ? '正在扫描中，是否确认退出？\n退出后扫描任务将自动停止。'
            : '确定要退出应用吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton.tonal(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('退出', style: TextStyle(color: Colors.red.shade400))),
        ],
      ),
    );

    if (confirmed == true) {
      _isExiting = true;

      if (isScanning && scanController != null) {
        scanController.confirmStop();
        await for (final state in scanController.stateStream) {
          if (state == ScanState.stopped) {
            break;
          }
        }
      }

      await Future.wait([
        _cleanupResources(scanController),
        _playExitAnimation(),
      ]);

      // 让 loading 动画至少展示约 1s，解决 destroy 过程阻塞主线程
      // 导致 spinner 卡死的视觉问题。
      await Future.delayed(const Duration(milliseconds: 600));

      await windowManager.destroy();
    }
  }

  Future<void> _cleanupResources(ScanController? scanController) async {
    try {
      scanController?.dispose();

      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      final db = ref.read(databaseProvider);
      await db.close();
    } catch (e) {
      debugPrint('资源清理失败: $e');
    }
  }

  Future<void> _playExitAnimation() async {
    await _exitAnimationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 监听浏览器刷新信号：扫描完成 / 删除 / 编辑标签时清空 ImageCache，
    // 防止缩略图缓存里残留旧引用。
    final refreshSignal = ref.watch(browserRefreshSignalProvider);
    if (refreshSignal != _lastRefreshSignal) {
      _lastRefreshSignal = refreshSignal;
      // 延后到下一帧，等所有 widget 处理完刷新
      WidgetsBinding.instance.addPostFrameCallback((_) {
        PaintingBinding.instance.imageCache.clear();
      });
    }

    return AnimatedBuilder(
      animation: _exitAnimationController,
      builder: (context, child) {
        return Stack(
          children: [
            Opacity(
              opacity: _exitOpacity.value,
              child: Transform.scale(
                scale: _exitScale.value,
                child: child,
              ),
            ),
            if (_isExiting)
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: _exitAnimationController,
                  curve: const Interval(0.2, 1.0),
                ),
                child: Container(
                  color: isDark ? Colors.black : Colors.white,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          '正在关闭应用...',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF12131A), const Color(0xFF1E1F2D)]
                  : [const Color(0xFFF6F7FB), const Color(0xFFEEF1F8)],
            ),
          ),
          child: Row(
            children: [
              _CapsuleNavRail(
                selectedIndex: ref.watch(currentPageProvider),
                items: _navItems,
                onSelect: (i) => ref.read(currentPageProvider.notifier).state = i,
              ),
              Expanded(
                child: IndexedStack(
                  index: ref.watch(currentPageProvider),
                  children: const [
                    BrowserPage(),
                    DashboardPage(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 胶囊风格侧边导航（替代 NavigationRail）
class _CapsuleNavRail extends ConsumerWidget {
  final int selectedIndex;
  final List<({IconData icon, IconData selectedIcon, String label})> items;
  final void Function(int) onSelect;

  const _CapsuleNavRail({
    required this.selectedIndex,
    required this.items,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeMode = ref.read(themeModeProvider.notifier);

    return Container(
      width: 84,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E1F2D).withOpacity(0.8)
            : Colors.white.withOpacity(0.7),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              // 顶部品牌小圆
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF6B9BFF), const Color(0xFF9B6BFF)]
                        : [const Color(0xFF5B8DEF), const Color(0xFF7B5BEF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: (isDark
                              ? const Color(0xFF6B9BFF)
                              : const Color(0xFF5B8DEF))
                          .withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (int i = 0; i < items.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: _CapsuleNavItem(
                            item: items[i],
                            selected: i == selectedIndex,
                            onTap: () => onSelect(i),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // 主题切换按钮
              const SizedBox(height: 8),
              _ThemeToggleButton(
                isDark: isDark,
                onToggle: () {
                  themeMode.state = isDark ? ThemeMode.light : ThemeMode.dark;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeToggleButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggle;
  const _ThemeToggleButton({required this.isDark, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2E3041) : const Color(0xFFF0F1F8),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          isDark ? Icons.light_mode : Icons.dark_mode,
          color: isDark ? const Color(0xFFFFD93D) : const Color(0xFF5B8DEF),
          size: 22,
        ),
      ),
    );
  }
}

class _CapsuleNavItem extends StatelessWidget {
  final ({IconData icon, IconData selectedIcon, String label}) item;
  final bool selected;
  final VoidCallback onTap;
  const _CapsuleNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: 60,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withOpacity(0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? item.selectedIcon : item.icon,
                size: 22,
                color: selected
                    ? scheme.primary
                    : (isDark
                        ? Colors.white.withOpacity(0.7)
                        : scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? scheme.primary
                      : (isDark
                          ? Colors.white.withOpacity(0.7)
                          : scheme.onSurfaceVariant),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
