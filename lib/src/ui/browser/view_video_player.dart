// ============================================================
// lib/src/ui/browser/view_video_player.dart
// 视频播放器组件：封装 video_player，处理播放失败的情况
// ============================================================
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../db/database.dart';

/// 视频播放器视图：支持播放视频，失败时显示友好提示
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
  late VideoPlayerController _controller;
  Future<void>? _initializeFuture;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  void _initPlayer() {
    _controller = VideoPlayerController.file(File(widget.item.filePath))
      ..setLooping(false);

    _initializeFuture = _controller.initialize().then((_) {
      setState(() {});
    }).catchError((e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_hasError) return;
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return _buildErrorView();
    }

    return FutureBuilder<void>(
      future: _initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return _buildPlayer();
        } else {
          return _buildLoadingView();
        }
      },
    );
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
          VideoPlayer(_controller),
          // 播放/暂停覆盖层
          if (!_controller.value.isPlaying)
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(32),
                ),
                child:
                    const Icon(Icons.play_arrow, color: Colors.white, size: 32),
              ),
            ),
          // 底部进度条
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _VideoControls(controller: _controller),
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
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                '无法播放视频',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? '未知错误',
                style: TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                widget.item.fileName,
                style: TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 视频控制栏：进度条 + 播放时间
class _VideoControls extends StatelessWidget {
  final VideoPlayerController controller;

  const _VideoControls({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 20,
            ),
            onPressed: () {
              if (controller.value.isPlaying) {
                controller.pause();
              } else {
                controller.play();
              }
            },
          ),
          Expanded(
            child: VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Colors.blue,
                bufferedColor: Colors.grey,
                backgroundColor: Colors.white24,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatDuration(controller.value.position) +
                ' / ' +
                _formatDuration(controller.value.duration),
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration? d) {
    if (d == null) return '--:--';
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    return '${d.inHours}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
