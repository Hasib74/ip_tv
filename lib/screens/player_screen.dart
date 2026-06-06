import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/stream_model.dart';

class PlayerScreen extends StatefulWidget {
  final StreamModel stream;

  const PlayerScreen({super.key, required this.stream});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  // Common
  bool _isYoutube = false;

  // For Normal Streams
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;

  // For Youtube
  YoutubePlayerController? _youtubeController;

  @override
  void initState() {
    super.initState();
    _checkUrlType();
  }

  void _checkUrlType() {
    final url = widget.stream.streamUrl;
    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      _isYoutube = true;
      _initializeYoutube();
    } else {
      _isYoutube = false;
      _initializeNormalPlayer();
    }
  }

  void _initializeYoutube() {
    String? videoId = YoutubePlayer.convertUrlToId(widget.stream.streamUrl);
    if (videoId != null) {
      _youtubeController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          isLive: true,
          mute: false,
        ),
      );
    }
  }

  Future<void> _initializeNormalPlayer() async {
    try {
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.stream.streamUrl));
      await _videoPlayerController!.initialize();

      if (!mounted) return;
      final colorScheme = Theme.of(context).colorScheme;

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        isLive: true,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        allowFullScreen: true,
        deviceOrientationsAfterFullScreen: [DeviceOrientation.portraitUp],
        fullScreenByDefault: false,
        placeholder: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: colorScheme.error, size: 42),
                const SizedBox(height: 10),
                Text(
                  "Stream link is broken or offline (404)",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          );
        },
      );
      setState(() {});
    } catch (e) {
      debugPrint("Error initializing player: $e");
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _youtubeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isYoutube && _youtubeController != null) {
      return YoutubePlayerBuilder(
        player: YoutubePlayer(
          controller: _youtubeController!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: colorScheme.primary,
        ),
        builder: (context, player) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: MediaQuery.of(context).orientation == Orientation.portrait
                ? AppBar(
                    backgroundColor: Colors.transparent,
                    title: Text(widget.stream.title, style: TextStyle(fontSize: 16, color: colorScheme.onSurface)),
                    iconTheme: IconThemeData(color: colorScheme.onSurface),
                  )
                : null,
            body: Center(child: player),
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: MediaQuery.of(context).orientation == Orientation.portrait
          ? AppBar(
              backgroundColor: Colors.transparent,
              title: Text(widget.stream.title, style: TextStyle(fontSize: 16, color: colorScheme.onSurface)),
              iconTheme: IconThemeData(color: colorScheme.onSurface),
            )
          : null,
      body: Center(
        child: _chewieController != null &&
                _chewieController!.videoPlayerController.value.isInitialized
            ? Chewie(controller: _chewieController!)
            : CircularProgressIndicator(color: colorScheme.primary),
      ),
    );
  }
}
