// ============================================================
// lib/src/ui/browser/view_video_player.dart
// 视频播放器组件：使用 media_kit (libmpv)，Windows/Linux 全格式支持
// ============================================================
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../db/database.dart';

class VideoPlayerView extends StatefulWidget {
  final MediaItem item;
  final double? width;
  final double? height;

  const VideoPlayerView({
    super.key,
    required this.item,
    this.width,
    this.height,
  });

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  late final Player _player;
  late final VideoController _controller;
  bool _initialized = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player = Player(
      configuration: const PlayerConfiguration(title: 'PicGuide'),
    );
    _controller = VideoController(_player);

    _player.stream.playing.listen((p) {
      if (mounted) setState(() => _isPlaying = p);
    });
    _player.stream.error.listen((e) {
      debugPrint('[Video] ERROR: $e');
    });

    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final path = widget.item.filePath;
    try {
      await _player.open(Media(path), play: false);
      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      debugPrint('[Video] open FAILED: $e');
      if (mounted) {
        setState(() { _hasError = true; _errorMessage = e.toString(); });
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_hasError) return;
    _player.playOrPause();
  }

  void _enterFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenVideoRoute(
          player: _player,
          controller: _controller,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) return _buildErrorView();
    if (!_initialized) return _buildLoadingView();
    return _buildPlayer();
  }

  Widget _buildLoadingView() {
    return Container(
      color: Colors.black,
      width: widget.width,
      height: widget.height,
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  Widget _buildPlayer() {
    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Video(controller: _controller, controls: NoVideoControls),
          // 中央播放按钮
          Center(
            child: _isPlaying
                ? const SizedBox.shrink()
                : Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: const Icon(Icons.play_arrow,
                        color: Colors.white, size: 32),
                  ),
          ),
          // 底部控制条
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _VideoControls(
              player: _player,
              controller: _controller,
              onFullscreen: _enterFullscreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Container(
      color: Colors.black,
      width: widget.width,
      height: widget.height,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              const Text('无法播放视频',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 8),
              Text(_errorMessage ?? '未知错误',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 全屏页面 ───

class _FullscreenVideoRoute extends StatefulWidget {
  final Player player;
  final VideoController controller;
  const _FullscreenVideoRoute({
    required this.player,
    required this.controller,
  });

  @override
  State<_FullscreenVideoRoute> createState() => _FullscreenVideoRouteState();
}

class _FullscreenVideoRouteState extends State<_FullscreenVideoRoute> {
  late final VideoController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Video(controller: _controller, controls: NoVideoControls),
          Positioned(
            top: 0, left: 0,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _VideoControls(
              player: widget.player,
              controller: _controller,
              onFullscreen: () => Navigator.pop(context),
              isFullscreen: true,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 底部控制条 ───

class _VideoControls extends StatefulWidget {
  final Player player;
  final VideoController controller;
  final VoidCallback? onFullscreen;
  final bool isFullscreen;

  const _VideoControls({
    required this.player,
    required this.controller,
    this.onFullscreen,
    this.isFullscreen = false,
  });

  @override
  State<_VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<_VideoControls> {
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  double _volume = 1.0;
  double _lastVolume = 1.0; // 静音前的音量，用于恢复
  OverlayEntry? _volumeOverlay;
  final _volumeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // 用同步 state 初始化，避免进入全屏等场景下错过流的历史值
    _position = widget.player.state.position;
    _duration = widget.player.state.duration;
    _playing = widget.player.state.playing;
    _volume = widget.player.state.volume;

    widget.player.stream.position.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    widget.player.stream.duration.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    widget.player.stream.playing.listen((p) {
      if (mounted) setState(() => _playing = p);
    });
    widget.player.stream.volume.listen((v) {
      if (mounted) setState(() => _volume = v);
    });
  }

  @override
  void dispose() {
    _volumeOverlay?.remove();
    super.dispose();
  }

  void _seek(double fraction) {
    widget.player.seek(_duration * fraction);
  }

  void _setVolume(double v) {
    widget.player.setVolume(v);
  }

  void _toggleMute() {
    if (_volume > 0) {
      _lastVolume = _volume;
      widget.player.setVolume(0);
    } else {
      widget.player.setVolume(_lastVolume <= 0 ? 0.5 : _lastVolume);
    }
  }

  void _toggleVolumePopup() {
    if (_volumeOverlay != null) {
      _volumeOverlay!.remove();
      _volumeOverlay = null;
      setState(() {});
      return;
    }

    final renderBox = _volumeKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final centerX = offset.dx + size.width / 2;
    final topY = offset.dy - 148; // 弹窗高度 140 + 间距 8

    _volumeOverlay = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          // 透明遮罩：点击关闭
          GestureDetector(
            onTap: () {
              _volumeOverlay?.remove();
              _volumeOverlay = null;
              setState(() {});
            },
            behavior: HitTestBehavior.translucent,
            child: Container(color: Colors.transparent),
          ),
          // 竖向滑块 — 定位在音量按钮正上方
          Positioned(
            left: centerX - 22,
            top: topY,
            child: _VolumeBox(volume: _volume, onChanged: _setVolume),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_volumeOverlay!);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 进度条（Slider 带拖拽节点，坐标精确）
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              thumbColor: Colors.blue,
              activeTrackColor: Colors.blue,
              inactiveTrackColor: Colors.white24,
              overlayColor: const Color.fromRGBO(33, 150, 243, 31),
            ),
            child: Slider(
              value: _duration.inMilliseconds > 0
                  ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
                  : 0,
              onChanged: (v) => _seek(v),
              onChangeEnd: (v) => _seek(v),
            ),
          ),
          // 按钮行
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _playing ? Icons.pause : Icons.play_arrow,
                  color: Colors.white, size: 20,
                ),
                onPressed: () => widget.player.playOrPause(),
              ),
              Expanded(
                child: Text(
                  '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
              // 音量按钮 — 单击弹出滑块，双击切换静音
              GestureDetector(
                key: _volumeKey,
                onTap: _toggleVolumePopup,
                onDoubleTap: _toggleMute,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    _volume <= 0
                        ? Icons.volume_off
                        : _volume < 0.5
                            ? Icons.volume_down
                            : Icons.volume_up,
                    color: Colors.white, size: 20,
                  ),
                ),
              ),
              // 全屏
              if (widget.onFullscreen != null)
                IconButton(
                  icon: Icon(
                    widget.isFullscreen
                        ? Icons.fullscreen_exit
                        : Icons.fullscreen,
                    color: Colors.white, size: 20,
                  ),
                  onPressed: widget.onFullscreen,
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${d.inHours}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

/// 竖向音量滑块弹窗（StatefulWidget，拖动时内部维护 value，不被 Overlay 截断更新）
class _VolumeBox extends StatefulWidget {
  final double volume;
  final ValueChanged<double> onChanged;
  const _VolumeBox({required this.volume, required this.onChanged});

  @override
  State<_VolumeBox> createState() => _VolumeBoxState();
}

class _VolumeBoxState extends State<_VolumeBox> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.volume;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 48,
        height: 140,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: RotatedBox(
                quarterTurns: -1,
                child: SliderTheme(
                  data: const SliderThemeData(
                    trackHeight: 4,
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
                  ),
                  child: Slider(
                    value: _value.clamp(0.0, 1.0),
                    onChanged: (v) {
                      setState(() => _value = v);
                      widget.onChanged(v);
                    },
                    activeColor: Colors.white,
                    inactiveColor: Colors.white24,
                  ),
                ),
              ),
            ),
            Text(
              '${(_value * 100).round()}%',
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
