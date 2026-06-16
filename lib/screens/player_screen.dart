import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:floating/floating.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../models/stream_model.dart';
import '../services/firebase_service.dart';

class PlayerScreen extends StatefulWidget {
  final StreamModel stream;

  const PlayerScreen({super.key, required this.stream});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  // Common
  bool _isYoutube = false;
  bool _isWebView = false;

  // For Normal Streams (media_kit)
  late final Player _player;
  late final VideoController _controller;
  bool _isInitialized = false;

  // For Youtube
  YoutubePlayerController? _youtubeController;

  // For WebView
  WebViewController? _webViewController;

  // For PiP
  late final Floating _floating;

  @override
  void initState() {
    super.initState();
    _floating = Floating();
    _checkUrlType();
    _enableAutoPip();
    
    // Increment viewer count
    FirebaseService().incrementViewerCount(widget.stream.id);
  }

  Future<void> _enableAutoPip() async {
    final canUsePip = await _floating.isPipAvailable;
    if (canUsePip) {
      await _floating.enable(const OnLeavePiP(aspectRatio: Rational.landscape()));
    }
  }

  void _checkUrlType() {
    final url = widget.stream.streamUrl;
    final type = widget.stream.streamType;

    if (type == 'webview' || type == 'iframe') {
      _isWebView = true;
      _initializeWebView();
      return;
    }

    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      _isYoutube = true;
      _initializeYoutube();
    } else {
      _isYoutube = false;
      _initializeMediaKit();
    }
  }

  void _initializeWebView() {
    if (kIsWeb) return; // Prevent WebView initialization on web platform

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            _injectCleaner();
          },
        ),
      );

    if (widget.stream.streamType == 'iframe') {
      _webViewController!.loadHtmlString('''
        <html>
          <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
              body { margin: 0; padding: 0; background: black; display: flex; justify-content: center; align-items: center; height: 100vh; overflow: hidden; }
              iframe { width: 100%; height: 100%; border: none; }
            </style>
          </head>
          <body>${widget.stream.streamUrl}</body>
        </html>
      ''');
    } else {
      _webViewController!.loadRequest(Uri.parse(widget.stream.streamUrl));
    }
  }

  void _injectCleaner() {
    final selector = widget.stream.webSelector;
    if (selector.isEmpty) return;

    // JavaScript to hide everything except the selected element
    final js = '''
      (function() {
        var target = document.querySelector('$selector');
        if (target) {
          // Hide all body children
          var children = document.body.children;
          for (var i = 0; i < children.length; i++) {
            children[i].style.display = 'none';
          }
          
          // Re-show target and move to body root if necessary
          document.body.appendChild(target);
          target.style.display = 'block';
          target.style.position = 'fixed';
          target.style.top = '0';
          target.style.left = '0';
          target.style.width = '100%';
          target.style.height = '100%';
          target.style.zIndex = '999999';
          target.style.backgroundColor = 'black';
          
          // Force video inside target to be full size
          var video = target.querySelector('video');
          if (video) {
            video.style.width = '100%';
            video.style.height = '100%';
          }
        }
      })();
    ''';
    _webViewController?.runJavaScript(js);
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
    if (!_isYoutube && !_isWebView) {
      _player.dispose();
    }
    _youtubeController?.dispose();
    _floating.cancelOnLeavePiP();

    // Decrement viewer count
    FirebaseService().decrementViewerCount(widget.stream.id);
    
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
    if (_isWebView) {
      if (kIsWeb) {
        // Use HtmlWidget for web to safely render iframe/webview content
        final htmlContent = widget.stream.streamType == 'iframe'
            ? widget.stream.streamUrl
            : '<iframe src="${widget.stream.streamUrl}" width="100%" height="100%" frameborder="0" allowfullscreen></iframe>';
        playerWidget = Container(
          color: Colors.black,
          child: HtmlWidget(htmlContent),
        );
      } else if (_webViewController != null) {
        playerWidget = WebViewWidget(controller: _webViewController!);
      } else {
        playerWidget = const Center(child: CircularProgressIndicator());
      }
    } else if (_isYoutube && _youtubeController != null) {
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

    // Wrap player with branding logo
    final brandedPlayer = Stack(
      children: [
        Center(child: playerWidget),
        if (!_isWebView)
          Positioned(
            top: 20,
            right: 20,
            child: Opacity(
              opacity: 0.5,
              child: Image.asset(
                'assets/images/icon.png',
                width: 90,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
          ),
      ],
    );

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
        body: Center(child: brandedPlayer),
      ),
      childWhenEnabled: brandedPlayer,
    );
  }
}

