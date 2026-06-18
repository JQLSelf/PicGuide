# PixelVault 项目记忆 (2026-06-16)

## 扫描引擎优化 (P0~P5)

### P0 — Isolate 真并行（已完成）
- 重写了 `service_media_scanner.dart`：删除顺序/并行/自适应三算法，只保留 Isolate 并行方式
- MD5 + EXIF 在 `compute(_computeFileMeta, ...)` 中于独立 Isolate 并行计算
- 删除了 `model_scan_algorithm.dart`、`service_device_info.dart`、`SCAN_ALGORITHM_IMPLEMENTATION.md`
- 简化了 `dialog_scan_config.dart`（仅路径确认，无算法选择）
- 更新了 `README.md` 和 `assets/USER_MANUAL.md`

### P1 — 丰富 ScanProgress 数据模型（已完成）
- `ScanProgress` 新增字段：`added`, `duplicates`, `updated`, `speed`, `eta`, `phase`(ScanPhase 枚举)
- `ScanProgress` 新增辅助方法：`ratio`, `speedLabel`, `etaLabel`
- `scanFolder` 在每次 yield 时计算速度和 ETA

### P2 — 非阻塞进度展示（已完成）
- 重写 `widget_scan_progress.dart`：`ScanProgressOverlay`(全屏遮罩) → `ScanProgressPanel`(内联面板)
- 面板支持展开/收起：收起时显示细进度条 + 文件名，展开时显示完整统计
- 集成到 `page_browser.dart`：面板嵌入内容区域顶部，不再遮挡界面
- `scanStateProvider` 类型从 `({bool scanning,...})` 改为 `ScanProgress?`

### P3 — 批量数据库预加载（已完成）
- `scanFolder` 开头调用 `db.getItemsByFolderPrefix(folderPath)` 一次性加载所有已知记录
- `MediaScanner` 新增实例字段 `_pathMap`(Map<String, MediaItem>) 和 `_md5Set`(Set<String>)
- `_indexFileWithMeta` 优先查内存，未命中才回退 DB 查询
- 新增 DB 方法 `getItemsByFolderPrefix`（`database.dart`）

### P4 — 暂停机制改为 Completer（已完成）
- `ScanController` 中 `_shouldPause`(bool) → `_pauseCompleter`(Completer<void>?)
- `pause()` 创建 Completer，`resume()` 调用 `complete()`
- `checkPause()` 改为 `await _pauseCompleter?.future`（零 CPU 忙等）
- `confirmStop()` 也会释放暂停锁，防止死锁

### P5 — 缩略图内存安全（已完成）
- 新增 `_Semaphore` 类（简单信号量，限制并发数）
- `MediaScanner` 新增 `_thumbSemaphore = _Semaphore(2)`（最多同时 2 个解码）
- `generateThumbnail` 改为通过 `_thumbWithSemaphore` 调用，内部用信号量保护
- 防止大图同时解码撑爆内存

## 文件夹树文字颜色适配（已完成）
- `page_browser.dart` 中 4 处图片数量文字（`node.fileCount`、子文件夹卡片等）改为明暗适配
- 白天 `black54/black45`，黑暗 `white70/white54`
