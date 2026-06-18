// ============================================================
// lib/src/services/service_scan_controller.dart
// 扫描控制器：管理扫描状态、暂停、停止、保存确认
// ============================================================
import 'dart:async';
import '../db/database.dart';

/// 扫描状态枚举
enum ScanState {
  scanning, // 正在扫描
  paused, // 已暂停
  stopping, // 正在停止（等待确认）
  stopped, // 已停止
  completed, // 已完成
}

/// 扫描控制器：管理扫描过程的暂停、停止和状态跟踪
class ScanController {
  final AppDatabase _db;

  ScanState _state = ScanState.stopped;
  bool _shouldStop = false;
  Completer<void>? _pauseCompleter;
  int _scannedCount = 0;
  int _addedCount = 0;
  int _duplicatesCount = 0;
  int _updatedCount = 0;

  final _stateStreamController = StreamController<ScanState>.broadcast();

  ScanController(this._db);

  /// 当前扫描状态
  ScanState get state => _state;

  /// 已扫描完成的数量
  int get scannedCount => _scannedCount;

  /// 已添加的数量
  int get addedCount => _addedCount;

  /// 状态流
  Stream<ScanState> get stateStream => _stateStreamController.stream;

  /// 暂停扫描（零 CPU 等待：用 Completer 阻塞 await）
  void pause() {
    if (_state == ScanState.scanning) {
      _pauseCompleter = Completer<void>();
      _updateState(ScanState.paused);
    }
  }

  /// 恢复扫描
  void resume() {
    if (_state == ScanState.paused) {
      _pauseCompleter?.complete();
      _pauseCompleter = null;
      _updateState(ScanState.scanning);
    }
  }

  /// 请求停止扫描（需要确认）
  void requestStop() {
    if (_state == ScanState.scanning || _state == ScanState.paused) {
      _updateState(ScanState.stopping);
    }
  }

  /// 确认停止扫描
  void confirmStop() {
    if (_state == ScanState.stopping) {
      _shouldStop = true;
      // 如果当前处于暂停状态，先释放暂停锁，让扫描循环能响应停止信号
      _pauseCompleter?.complete();
      _pauseCompleter = null;
      _updateState(ScanState.stopped);
    }
  }

  /// 取消停止请求
  void cancelStop() {
    if (_state == ScanState.stopping) {
      _updateState(_pauseCompleter != null ? ScanState.paused : ScanState.scanning);
    }
  }

  /// 记录扫描进度
  void recordProgress(int scanned, int added, int duplicates, int updated) {
    _scannedCount = scanned;
    _addedCount = added;
    _duplicatesCount = duplicates;
    _updatedCount = updated;
  }

  /// 检查是否需要暂停（零 CPU 等待）
  /// 调用方 await checkPause() —— 暂停时这里会挂起，恢复时自动继续
  Future<void> checkPause() async {
    if (_pauseCompleter != null) {
      await _pauseCompleter!.future;
    }
  }

  /// 检查是否需要停止
  bool shouldStop() => _shouldStop;

  /// 标记扫描完成
  void complete() {
    _updateState(ScanState.completed);
  }

  /// 重置状态（准备新扫描）
  void reset() {
    _state = ScanState.stopped;
    _shouldStop = false;
    _pauseCompleter?.complete(); // 防止遗漏的暂停导致死锁
    _pauseCompleter = null;
    _scannedCount = 0;
    _addedCount = 0;
    _duplicatesCount = 0;
    _updatedCount = 0;
  }

  /// 更新扫描状态
  void updateState(ScanState newState) {
    _state = newState;
    _stateStreamController.add(newState);
  }

  void _updateState(ScanState newState) {
    updateState(newState);
  }

  /// 释放资源
  void dispose() {
    _pauseCompleter?.complete(); // 防止遗漏
    _pauseCompleter = null;
    _stateStreamController.close();
  }
}
