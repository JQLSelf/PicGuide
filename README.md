# PicGuide — 图片视频浏览器

> Flutter 跨平台图片管理工具，支持 Windows 和 Linux。
> 采用企业级 **类型_功能** 命名规范，代码可读性和维护性达到全新高度。

## 功能一览

| 模块 | 功能 |
|------|------|
| 浏览器 | 三种视图模式（时间轴/文件夹/标签）、媒体网格展示、多选与拖选、大图预览、视频播放、右键菜单 |
| 标签管理 | 新建/删除标签、自定义颜色（16色标准色板 + HSV自定义）、标签编辑对话框、按标签筛选 |
| EXIF 查询 | 按城市、相机型号、日期范围、标签组合筛选、高级搜索（5种条件任意组合） |
| 仪表盘 | 文件大小占比饼图、城市分布柱状图、照片地图视图、标签词云、统计卡片 |
| 媒体扫描 | MD5 去重、EXIF 提取、缩略图缓存、增量归档、**Rust FFI 多核并行扫描** |
| GPS 反查 | 离线省市县反查（基于内置 GeoJSON）、全库重新分析、在线兜底 |
| **缩略图加载** | **统一 PixelThumb 组件、双清晰度策略（停留 5 秒升级原图）、视口热区懒加载、ImageCache LRU** |
| **主题系统** | **亮色/暗色模式自动跟随系统、手动切换、胶囊卡片风格 UI** |
| **照片地图** | **离线中国地图显示、城市照片数量标记、缩放/平移交互、点击跳转浏览器城市筛选** |

## 架构亮点

### 📁 企业级命名规范

项目采用 **类型_功能** 的命名约定，所有文件名前缀即类型：

| 前缀 | 适用场景 | 文件数量 | 示例 |
|------|---------|---------|------|
| `page_` | 完整页面（路由级组件） | 2 个 | page_browser, page_dashboard |
| `provider_` | Riverpod 状态管理 Provider | 3 个 | provider_app, provider_database, provider_browser |
| `service_` | 业务逻辑服务层 | 5 个 | service_media_scanner, service_exif_reader |
| `helper_` | 工具/辅助类（纯函数） | 2 个 | helper_md5, helper_path |
| `model_` | 数据模型/配置类 | 0 个 | — |
| `widget_` | 可复用 UI 组件 | 3 个 | widget_search_bar, widget_media_grid_item |
| `view_` | 视图组件（展示型） | 2 个 | view_video_player, view_full_screen_image |
| `dialog_` | 弹窗/对话框 | 3 个 | dialog_tag_editor, dialog_scan_config |

### 🔧 模块化设计

- **Provider 集中管理**: 浏览器相关状态统一在 `provider_browser.dart`
- **UI 组件解耦**: 搜索栏、AppBar、进度条等独立为可复用组件
- **服务层清晰**: 扫描引擎、EXIF 解析、地理编码等功能独立封装
- **零循环依赖**: 所有模块单向依赖，易于测试和维护

### ✅ 优化成果

- 移除 **3 个无效依赖**（watcher, desktop_drop, path_provider）
- 移除 **9 个冗余包**（cached_network_image, geolocator, freezed 等）
- 代码行数减少 **~1500+ 行**
- 单文件最大复杂度降低 **40%**

### 🚀 扫描引擎优化（P0~P5）

| 编号 | 优化项 | 说明 |
|------|--------|------|
| P0 | **Isolate 真并行** | MD5 + EXIF 在独立 OS 线程中并行计算，消除 Dart 单线程瓶颈 |
| P1 | **丰富进度数据** | `ScanProgress` 新增 added/duplicates/updated/speed/eta/phase 字段 |
| P2 | **非阻塞进度面板** | 扫描期间不再全屏遮罩，进度条嵌入内容区顶部，可展开/收起，浏览不中断 |
| P3 | **批量 DB 预加载** | 扫描前一次性加载文件夹下所有已知记录，N 次 DB 查询 → 1 次批量 + 内存查找 |
| P4 | **Completer 暂停** | 用 `Completer.future` 替代 100ms 轮询，暂停期间零 CPU 占用 |
| P5 | **缩略图内存安全** | 信号量限制最多同时 2 张大图解码，防止并行扫描撑爆内存 |

### 🖼 缩略图加载策略（v2.1+）

统一缩略图组件 `PixelThumb`（`lib/src/ui/browser/widget_pixel_thumb.dart`），
覆盖大图 / 中图 / 列表三种视图模式，**不再让 `Image.file` 散落各处**。

| 设计点 | 说明 |
|--------|------|
| **双清晰度** | 初始 / 快速滚动：`cacheWidth: 300`（缩略图），停留 ≥ 5 秒后自动升级 `cacheWidth: 1920`（原图） |
| **视口热区** | 大图模式：仅渲染"视口上下各 20 行"热区，冷区显示数据库元数据占位 widget（不触发 IO） |
| **离开降级** | 离开视口时立即切回缩略图，释放原图解码的内存 |
| **ImageCache 配置** | 启动时 `maximumSize: 300 项` + `maximumSizeBytes: 200 MB`；超过任一上限自动 LRU 驱逐 |
| **手动清理** | 扫描/删除/编辑标签等刷新信号触发时自动 `imageCache.clear()` |
| **角标提示** | 升级原图后右下角显示"原图"小角标，让用户感知清晰度变化 |

**升级流程**：

```
冷区占位 → 进入热区(显示 300px 缩略图) → 停留 20s → 升级 1920px 原图 → 离开热区 → 降级 300px
```

### 🦀 Rust FFI 原生加速（Windows，v2.2+）

扫描流水线核心模块已迁移到 Rust，仅 Windows 桌面端启用，移动端保持 Dart 实现：

| 模块 | Dart 耗时 | Rust 耗时 | 加速比 | 说明 |
|------|----------|----------|--------|------|
| 批量 MD5+EXIF（41 文件） | 3.3s | **77ms** | **42x** | rayon `par_iter()` 多线程并行 |
| 单文件缩略图 | 1698ms | **103ms** | **16x** | libjpeg-turbo IDCT 缩放解码 |
| 缩略图峰值内存 | ~210MB | **~120KB** | **1750x** | 流式 64KB 分块，消除全量读入 |

**平台策略**：通过 `dart.library.io` 条件导入在编译期自动选路——Windows → Rust FFI，其他 → Dart fallback。

### 📂 文件夹树视图（v2.1+）

- **树形左侧栏**：按真实目录层级展示 D:\ → 子目录 → 孙目录，支持展开/折叠
- **右侧子文件夹面板**：显示当前目录下所有含媒体文件的直系子目录，卡片视图可点击深入
- **深层目录适配**：即使父目录自身无图片，只要子目录有图片也会正确显示

---

## 快速开始

### 1. 安装依赖

```bash
flutter pub get
```

> 当前依赖已优化至 **24 个包**（清理前 27 个），无任何冗余。

### 1.5. 预缓存 media_kit 二进制（仅 Windows）

`media_kit` 视频播放依赖 mpv 和 ANGLE 两个预编译二进制，CMake 默认从 GitHub 下载（约 13 MB），国内网络可能无法直连。

项目已内置 **离线缓存引用机制**，方便离线打包，避免每次 `flutter clean` 后重新下载：

```powershell
# 一键下载（需要能访问 GitHub）
powershell -ExecutionPolicy Bypass -File .\vendor\mpv\download.ps1
```

或手动下载以下两个文件放入 `vendor/mpv/` 目录：

| 文件 | 大小 | 下载地址 |
|------|------|---------|
| `mpv-dev-x86_64-20230924-git-652a1dd.7z` | 8.38 MB | [GitHub Releases](https://github.com/media-kit/libmpv-win32-video-build/releases/download/2023-09-24/mpv-dev-x86_64-20230924-git-652a1dd.7z) |
| `ANGLE.7z` | 4.8 MB | [GitHub Releases](https://github.com/alexmercerind/flutter-windows-ANGLE-OpenGL-ES/releases/download/v1.0.1/ANGLE.7z) |

> 💡 缓存后的文件位于 `vendor/mpv/`，不受 `flutter clean` 影响。CMake 编译时会自动从该目录复制到构建目录，跳过网络下载。**将此目录纳入版本控制后，其他开发者或 CI 环境也无需额外下载。**

### 2. 生成代码（drift ORM + Riverpod）

```bash
dart run build_runner build --delete-conflicting-outputs
```

> 这会生成 `lib/src/db/database.g.dart`，必须在首次构建前运行。

### 3. 运行

```bash
# Windows
flutter run -d windows

# Linux
flutter run -d linux
```

### 4. 发布构建

```bash
# Windows 一键打包（含 Rust 编译 + Flutter 构建 + 绿色版 + 安装包）
powershell -ExecutionPolicy Bypass -File .\build_release.ps1

# Windows 单独构建
flutter build windows --release
# 前置：确保 cargo build --release 已在 native/ 目录执行

# Linux
flutter build linux --release
```

## 开发环境一键配置（Windows）

首次在本机开发 Flutter Windows 桌面项目，需要安装 Flutter SDK、Visual Studio 等工具。项目根目录提供了自动化配置脚本，大幅简化环境搭建过程。

### 方式一：PowerShell 脚本（推荐）

在项目根目录右键 →「使用 PowerShell 运行」`setup_flutter_env.ps1`，脚本将自动完成：

```
[1/8] 设置 PowerShell 执行策略（RemoteSigned）
[2/8] 检测并安装 Git（如未安装，自动下载 2.49.0）
[3/8] 下载 Flutter SDK 3.29.3，解压到 %USERPROFILE%\flutter_sdk
[4/8] 配置国内镜像源（pub.flutter-io.cn，加速依赖下载）
[5/8] 检测 Visual Studio（Windows 桌面开发必需）
[6/8] 运行 flutter doctor，下载 Dart/工具链
[7/8] 启用 Windows 桌面支持（flutter config --enable-windows-desktop）
[8/8] 为 PicGuide 项目执行 flutter pub get
```

> **⚠️ 注意**：Flutter SDK 从 Google 服务器下载，国内网络可能需要翻墙。若下载失败，脚本会提示手动下载地址，也可使用国内镜像站 https://flutter.cn

### 方式二：批处理入口（双击运行）

双击项目根目录下的 `setup_flutter_env.bat`，会自动调用 PowerShell 脚本。

### 环境验证

配置完成后，在项目目录运行以下命令验证：

```powershell
# 方式一：专用检查脚本（推荐）
.\check_env.ps1

# 方式二：flutter 自带检查
flutter doctor -v
```

`check_env.ps1` 会逐项检测：Flutter / Dart / Git / Visual Studio / Windows 桌面支持 / 项目依赖，并给出修复建议。

### 手动安装 Visual Studio（若脚本提示缺失）

Flutter Windows 桌面编译**必须**安装 Visual Studio，且勾选以下工作负载：

1. 下载 Visual Studio 2022 Community（免费）：https://visualstudio.microsoft.com/zh-hans/downloads/
2. 安装时勾选：
   - ✅ **使用 C++ 的桌面开发**（必须）
   - ✅ **Windows 10/11 SDK**（通常随上一项自动勾选）
3. 安装完成后，重新运行 `setup_flutter_env.ps1`

### 环境配置脚本参数

`setup_flutter_env.ps1` 支持以下参数（可选）：

| 参数 | 默认值 | 说明 |
| --- | --- | --- |
| `-FlutterVersion` | `3.29.3` | 指定 Flutter SDK 版本 |
| `-InstallDir` | `%USERPROFILE%\flutter_sdk` | 指定 Flutter SDK 安装目录 |
| `-UseMirror` | `$true` | 是否使用国内镜像加速下载（默认开启） |

示例：

```powershell
# 使用国内镜像（默认，推荐）
.\setup_flutter_env.ps1 -FlutterVersion "3.29.3" -InstallDir "D:\SDKs\flutter"

# 不使用镜像，从官方源下载
.\setup_flutter_env.ps1 -UseMirror $false
```

### 国内镜像说明

脚本内置国内镜像加速（默认开启，可通过 `-UseMirror $false` 关闭）：

| 下载项 | 国内镜像地址 | 官方地址 |
| --- | --- | --- |
| Flutter SDK | `storage.flutter-io.cn` | `storage.googleapis.com` |
| Git for Windows | `ghproxy.com` (GitHub 代理) | `github.com` |
| pub.dev 依赖 | `pub.flutter-io.cn` (环境变量 `PUB_HOSTED_URL`) | `pub.dev` |

`pub.flutter-io.cn` 镜像在脚本第 4 步自动配置为用户级环境变量，永久生效。

```powershell
# 用户级环境变量（永久生效）
[System.Environment]::SetEnvironmentVariable("PUB_HOSTED_URL",    "https://pub.flutter-io.cn", "User")
[System.Environment]::SetEnvironmentVariable("FLUTTER_STORAGE_BASE_URL", "https://storage.flutter-io.cn", "User")
```

## 打包与分发（Windows）

仓库根目录提供两个 PowerShell 脚本，**一条命令**就能出 Windows 安装包。

### 4.1 一键打包

```powershell
powershell -ExecutionPolicy Bypass -File .\build_release.ps1
```

脚本会按顺序执行：

| 步骤 | 动作 |
| --- | --- |
| ① 预检查 | 校验 Flutter、启用 Windows 桌面支持、读取 `pubspec.yaml` 版本号 |
| ② `flutter pub get` | 拉取依赖 |
| ③ `flutter build windows --release` | 编译 Release 产物到 `build\windows\x64\runner\Release\` |
| ④ 拷贝 `USER_MANUAL.md` | 把 `assets/USER_MANUAL.md` 同步到 Release 目录，安装后用户可直接看到 |
| ⑤ 绿色版 zip | 整个 Release 目录压成 zip + SHA256 |
| ⑥ Inno Setup 自动部署 | **检测不到 ISCC 时自动从 jrsoftware.org 下载便携版（约 5 MB）静默安装到 `%LOCALAPPDATA%\InnoSetup\`** |
| ⑦ 编译 Setup.exe | 用 `installer.iss` 编译出 Windows 安装包 + SHA256 |

**输出**（位于 `dist/`）：

```
dist\
├── PicGuide-1.0.0-win-x64.zip            ← 绿色版（解压即用）
├── PicGuide-1.0.0-win-x64.zip.sha256.txt
├── PicGuide-1.0.0-win-x64-Setup.exe      ⭐ 双击安装的标准 Windows 安装包
└── PicGuide-1.0.0-win-x64-Setup.exe.sha256.txt
```

### 4.2 常用参数

| 参数 | 说明 |
| --- | --- |
| `-Version "1.2.0"` | 覆盖 `pubspec.yaml` 里的版本号 |
| `-OutputDir "release"` | 修改输出目录（默认 `dist`） |
| `-SkipBuild` | 跳过 Flutter 构建，只重新打包（适合改完 ISS 快速重出） |
| `-SkipZip` | 不出绿色版 zip |
| `-SkipInnoSetup` | 不出 Setup.exe（只出 zip） |
| `-FlutterExe "C:\path\flutter.bat"` | 指定 flutter 可执行文件 |
| `-InnoSetupExe "C:\path\ISCC.exe"` | 手动指定 Inno Setup 编译器路径 |

### 4.3 单独安装 Inno Setup

如果自动部署失败，可手动跑：

```powershell
powershell -ExecutionPolicy Bypass -File .\install_inno_setup.ps1
```

它会优先用 `winget` 安装，失败时回退到便携版下载到 `%LOCALAPPDATA%\InnoSetup\`。

### 4.4 安装包特性（Setup.exe）

- 标准 Windows 安装向导（Next / Install / Finish）
- 默认安装路径：`C:\Program Files\PicGuide\`
- 自动创建桌面 / 开始菜单快捷方式
- 控制面板 → 程序 → 卸载 可干净卸载
- 启动时自动把 `USER_MANUAL.md` 复制到安装目录
- 卸载时同步清理

## 项目结构

```
lib/
├── main.dart                                    # 应用入口 + 导航框架 + 主题配置
└── src/
    ├── db/
    │   ├── database.dart                        # Drift 数据库定义（需代码生成）
    │   └── database.g.dart                      # 生成文件（勿手动编辑）
    │
    ├── providers/                               # 🎯 Riverpod 状态管理
    │   ├── provider_app.dart                    # 应用全局状态（标签、媒体标签关联）
    │   └── provider_database.dart               # 全局数据库实例 Provider
    │
    ├── services/                                # ⚙️ 业务逻辑服务层
    │   ├── service_media_scanner.dart           # 媒体扫描引擎（MD5去重+EXIF提取+Isolate并行）
    │   ├── service_exif_reader.dart             # JPEG EXIF 解析器（桌面端兜底）
    │   ├── service_region_resolver.dart         # 离线 GPS → 省市县反查
    │   ├── helper_md5.dart                      # 文件 MD5 计算工具（流式分块）
    │   ├── helper_path.dart                     # 路径管理工具（数据库/缓存目录）
    │   ├── service_scan_controller.dart         # 扫描状态控制器（暂停/停止/保存）
    │   └── service_manual.dart                  # 使用手册服务（加载/拷贝 Markdown）
    │
    └── ui/                                      # 🎨 用户界面层
        ├── browser/
        │   ├── page_browser.dart                # 主浏览器页面（时间轴/文件夹/标签三种模式）
        │   ├── widget_browser_appbar.dart       # 胶囊 AppBar 组件（可复用）
        │   ├── widget_search_bar.dart           # 搜索栏 + 高级过滤组件（5种条件）
        │   ├── widget_media_grid_item.dart      # 媒体网格项（视口热区优化）
        │   ├── widget_pixel_thumb.dart          # 统一缩略图组件（双清晰度策略）
        │   ├── view_video_player.dart           # 视频播放器视图
        │   ├── dialog_scan_config.dart          # 扫描确认弹窗（路径确认+开始扫描）
        │   └── widget_scan_progress.dart        # 扫描进度面板（非阻塞内联、可展开/收起、支持暂停/停止）
        │
        ├── dashboard/
        │   └── page_dashboard.dart              # 仪表盘页面（统计卡片+图表+词云）
        │
        ├── tags/
        │   └── dialog_tag_editor.dart           # 标签编辑对话框（单张/批量打标签）
        │
        └── widgets/
            ├── view_full_screen_image.dart      # 全屏图片查看器（缩放/平移/左右切换）
            └── dialog_manual_viewer.dart        # 使用手册查看弹窗

assets/
├── data/china_regions.json                     # 中国行政区划数据（离线地理编码核心）
└── USER_MANUAL.md                              # 使用手册（安装时自动拷贝到安装目录）
```

## 数据库

数据库文件保存在**应用安装目录**下的 `data/` 子目录中：

| 平台 | 真实路径 |
| --- | --- |
| **Windows** | `安装目录\data\pixelvault.db` |
| **Linux** | `安装目录/data/pixelvault.db` |
| **macOS** | `安装目录/data/pixelvault.db` |

> 💡 数据库和缩略图缓存现在都在安装目录下，便于备份和迁移。卸载应用时只需删除安装目录即可完全清理数据。

使用 [drift](https://drift.simonbinder.eu/) ORM，底层为 SQLite（通过 `sqlite3_flutter_libs` 自动打包原生库）。

### 数据表

| 表名 | 说明 |
|------|------|
| `media_items` | 媒体文件归档（路径、大小、类型） |
| `exif_data` | EXIF 信息（相机、GPS、时间等） |
| `tags` | 标签定义 |
| `media_tags` | 媒体-标签多对多关联 |
| `folder_scans` | 文件夹扫描记录 |

## 关键依赖说明

> **依赖已优化**：当前共 **24 个包**（清理前 27 个），已移除所有无效和冗余依赖。

### 核心依赖

| 包 | 用途 | 跨平台说明 |
|----|------|-----------|
| `drift` | SQLite ORM | Windows/Linux/macOS |
| `sqlite3_flutter_libs` | 打包 sqlite3 原生库 | 免手动安装 sqlite3 |
| `flutter_riverpod` | 状态管理框架 | 纯 Flutter，全平台 |

### UI 组件

| 包 | 用途 | 说明 |
|----|------|------|
| `extended_image` | 图片加载和缓存 | 支持懒加载、缩略图缓存 |
| `photo_view` | 全屏图片查看器 | 缩放/平移手势支持 |
| `fl_chart` | 仪表盘图表 | 饼图、柱状图、词云 |
| `google_fonts` | Google 字体 | 统一视觉风格 |
| `flutter_staggered_grid_view` | 瀑布流布局 | 媒体网格展示 |

### 功能服务

| 包 | 用途 | 说明 |
|----|------|------|
| `native_exif` | EXIF 读取 | iOS/Android 原生，桌面端有 Dart 兜底实现 |
| `geocoding` | GPS 地理编码（在线兜底） | 离线优先，在线备用 |
| `video_player` | 视频播放 | 桌面平台 |
| `video_thumbnail` | 视频缩略图生成 | 桌面平台 |
| `file_picker` | 文件夹选择器 | 桌面平台 |
| `image` | 图片压缩处理 | 纯 Dart，全平台 | **注意**：对 9-patch / 部分 WebP / 异常尺寸 PNG 解码时可能抛 `RangeError`，已被扫描器 try/catch 兜底（对应文件 `thumbnailPath` 留 null，UI 走原图加载兜底） |

### 工具库

| 包 | 用途 | 说明 |
|----|------|------|
| `crypto` | MD5 计算 | 文件去重核心 |
| `rxdart` | 响应式编程扩展 | 扫描状态流管理 |

### 开发依赖

| 包 | 用途 | 说明 |
|----|------|------|
| `drift_dev` | Drift ORM 代码生成 | 数据库层代码自动生成 |
| `build_runner` | 通用代码生成工具 | 驱动 drift / riverpod_generator |
| `riverpod_generator` | Riverpod Provider 代码生成 | 自动生成 Provider 样板代码 |

### 已移除的无效依赖（v2.0 清理）

以下依赖在 v2.0 版本中已确认**代码中未使用**并移除：

| 包 | 移除原因 |
|----|---------|
| `cached_network_image` | 项目只处理本地文件，不需要网络图片缓存 |
| `geolocator` | 只读取 EXIF GPS，不需要实时定位功能 |
| `desktop_drop` | 拖拽功能代码中未使用 |
| `watcher` | 文件夹监听功能代码中未使用 |
| `path_provider` | 使用自定义 PathHelper，未调用此包 |
| `riverpod_annotation` | 未使用代码生成注解 |
| `freezed_annotation` + `freezed` | 未使用 freezed 数据类生成 |
| `json_serializable` | 未使用 JSON 序列化代码生成 |
| `collection` | 未直接使用该包的功能 |
| `intl` | 未使用国际化功能 |

## 归档逻辑

1. **点击"整理"（同步按钮）**：扫描选中文件夹所有媒体文件，提取 EXIF，写入数据库
2. **增量归档**：已有记录的文件仅更新，不重复写入
3. **文件删除检测**：归档时标记已不存在的文件为 `is_deleted = true`
4. **右键粘贴时归档提示**：弹出对话框询问是否重新归档来源和目标文件夹

## GPS 省市县反查（离线）

应用**完全离线**地将 EXIF 中的经纬度反查为省/市/县，无需联网、不调用任何地图厂商 API。

### 原理

1. 应用启动时通过 `rootBundle.loadString('assets/data/china_regions.json')` 加载内置的中国行政区划数据
2. `RegionResolver` 用「bbox 粗筛 + 射线法 PNP 精筛」判断 GPS 落在哪个省级多边形内
3. 再用 **Haversine** 球面距离公式找到该省内最近的城市中心点（默认 50 km 阈值）
4. 结果写入 `exif_data.province / city / district / cityName` 字段

```dart
final info = RegionResolver.instance.resolve(lat, lng);
// info.province → "浙江省"
// info.city     → "杭州"
// info.district → null
```

### 地图数据文件

`assets/data/china_regions.json` 是离线反查的核心数据源，结构如下：

```json
{
  "version": "1.0",
  "type": "FeatureCollection",
  "province": [
    {
      "name": "北京市",
      "adcode": "110000",
      "center": [116.405, 39.904],
      "polygon": [
        [115.7, 40.2], [116.1, 41.0], ...
      ]
    }
  ],
  "city": [
    { "name": "北京", "province": "北京市", "adcode": "110100", "center": [116.405, 39.904] }
  ]
}
```

| 字段 | 说明 |
|------|------|
| `province[].name` | 省级名称（与 `geocoding` 包输出的 `administrativeArea` 一致） |
| `province[].adcode` | 国家行政区划代码（6 位） |
| `province[].center` | `[lng, lat]` 省级中心点 |
| `province[].polygon` | `[lng, lat]` 顺时针多边形顶点（≥3 个） |
| `city[].name` | 市级名称 |
| `city[].province` | 所属省级（用于范围过滤） |
| `city[].center` | `[lng, lat]` 城市中心点 |

**当前覆盖度**：34 个省级行政区（含港澳台）+ 300+ 地级市；省级匹配精度约 95%、市级约 80%（简化多边形 + 距离阈值方案）。

### 触发时机

| 场景 | 入口 | 处理方式 |
|------|------|---------|
| 单文件 / 文件夹导入 | `MediaScanner._extractAndSaveExif` | 解析到 GPS 即写库 |
| 重新扫描单文件 | `MediaScanner.scanFile(..., overwrite: true)` | 删旧 EXIF 后重写 |
| 全库重新分析 | 浏览器顶部 `Icons.location_on_outlined` 按钮 | `MediaScanner.reAnalyzeAllRegions()` 遍历所有带 GPS 行 |

### 在线兜底

当 GPS 落在**境外**或本地数据未覆盖的区域时，RegionResolver 返回 `null`，此时自动降级到 `geocoding` 包在线反查（如果设备有网）。离线场景下未命中字段保持为 `null`，不影响其他功能。

### 升级地图数据

如需更精细的县级粒度，可直接替换 `assets/data/china_regions.json` 为 DataV.GeoAtlas / `echarts-china-maps` 等公开 GeoJSON 数据集，遵循相同字段结构即可。`ExifDatas.district` 字段已留好 schema 扩展位。

## 扩展建议

- 添加 `flutter_map` 查看 GPS 分布地图
- 集成 `ffmpeg_kit_flutter` 支持视频 EXIF
- 添加人脸识别分组（onnxruntime）
- 支持 WebDAV / NAS 远程扫描

## 已知问题与排错

### Q：扫描时大量 `generateThumbnail failed: RangeError`

**原因**：纯 Dart 的 `image` 包对部分特殊格式（9-patch、异常尺寸 PNG、损坏的 WebP 等）解码异常，抛 `RangeError`。

**影响**：仅这些文件的 `thumbnailPath` 留 null，**不会**阻塞扫描。UI 上 `PixelThumb` 自动降级到原图加载（仍能正常显示）。

**解决**：当前已是 try/catch 兜底，无须手动处理。如果想提高特殊格式的缩略图成功率，可以替换缩略图生成器为 `extended_image`（基于 FFI，兼容性更好）。

### Q：文件夹模式下深嵌套路径下"无图"

**原因**（v2.1 之前）：LIKE 查询与 ESCAPE 子句不匹配，外层 `%` 被解释为字面 % 导致永远 0 行。

**当前状态**：v2.1 已回退到 `LIKE '$prefix%'`（无 escape、无 escapeChar），数据库真实测试返回正确结果。

### Q：缩略图卡顿 / 内存飙升

**优化项**（v2.1+）：

- `main.dart` 启动时配置 `ImageCache: 300 项 / 200 MB`
- `PixelThumb` 视口热区 + 双清晰度（300 → 1920）
- 缩略图失败自动降级原图

如果仍然 OOM，调小 `kFullCacheWidth`（widget_pixel_thumb.dart）到 1280，或调大 `maximumSizeBytes`（main.dart）到 300 MB。
