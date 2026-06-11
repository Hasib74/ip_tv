import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:floating/floating.dart';
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

  // For Normal Streams (media_kit)
  late final Player _player;
  late final VideoController _controller;
  bool _isInitialized = false;

  // For Youtube
  YoutubePlayerController? _youtubeController;

  // For PiP
  late final Floating _floating;

  @override
  void initState() {
    super.initState();
    _floating = Floating();
    _checkUrlType();
    _enableAutoPip();
  }

  Future<void> _enableAutoPip() async {
    final canUsePip = await _floating.isPipAvailable;
    if (canUsePip) {
      await _floating.enable(const OnLeavePiP(aspectRatio: Rational.landscape()));
    }
  }

  void _checkUrlType() {
    final url = widget.stream.streamUrl;
    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      _isYoutube = true;
      _initializeYoutube();
    } else {
      _isYoutube = false;
      _initializeMediaKit();
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

  Future<void> _initializeMediaKit() async {
    _player = Player();
    _controller = VideoController(_player);
    
    _player.stream.error.listen((event) {
      debugPrint("MediaKit Error: $event");
    });

    await _player.open(Media(widget.stream.streamUrl));
    
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    if (!_isYoutube) {
      _player.dispose();
    }
    _youtubeController?.dispose();
    _floating.cancelOnLeavePiP();
    super.dispose();
  }

  Future<void> _enablePip() async {
    final canUsePip = await _floating.isPipAvailable;
    if (canUsePip) {
      await _floating.enable(const ImmediatePiP(aspectRatio: Rational.landscape()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget playerWidget;
    if (_isYoutube && _youtubeController != null) {
      playerWidget = YoutubePlayerBuilder(
        player: YoutubePlayer(
          controller: _youtubeController!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: colorScheme.primary,
        ),
        builder: (context, player) => player,
      );
    } else {
      playerWidget = _isInitialized
          ? Video(controller: _controller)
          : CircularProgressIndicator(color: colorScheme.primary);
    }

    return PiPSwitcher(
      childWhenDisabled: Scaffold(
        backgroundColor: Colors.black,
        appBar: MediaQuery.of(context).orientation == Orientation.portrait
            ? AppBar(
                backgroundColor: Colors.transparent,
                title: Text(widget.stream.title,
                    style: TextStyle(fontSize: 16, color: colorScheme.onSurface)),
                iconTheme: IconThemeData(color: colorScheme.onSurface),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.picture_in_picture_alt, color: Colors.red,),
                    onPressed: _enablePip,
                  ),
                ],
              )
            : null,
        body: Center(child: playerWidget),
      ),
      childWhenEnabled: playerWidget,
    );
  }
}

