import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:floating/floating.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/stream_model.dart';
import '../services/firebase_service.dart';
import '../services/ad_service.dart';

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
  bool _isBuffering = false;

  // For Youtube
  YoutubePlayerController? _youtubeController;

  // For WebView
  WebViewController? _webViewController;

  // For PiP
  late final Floating _floating;
@override
  void initState() {
    super.initState();
    AdService.setPlaybackActive(true);
    _floating = Floating();
    _checkUrlType();
    _enableAutoPip();
    
    // Increment viewer count
    AppFirebaseService().incrementViewerCount(widget.stream.id);
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

    // Optimize for HLS (m3u8) loading speed and smoothness
    try {
      final platform = _player.platform as dynamic;
      
      // Mimic a desktop browser to avoid server throttling
      platform.setProperty('user-agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36');
      
      // Hardware Acceleration
      platform.setProperty('hwdec', 'auto');
      
      // Low Latency & Smoothness for Live Streams
      platform.setProperty('profile', 'low-latency');
      platform.setProperty('vd-lavc-fast', 'yes');
      platform.setProperty('avsync', 'ext');
      platform.setProperty('framedrop', 'vo');
      
      // Aggressive Buffer & Cache Settings (Prevent constant buffering)
      platform.setProperty('demuxer-max-bytes', '104857600'); // 100MB
      platform.setProperty('demuxer-max-back-bytes', '52428800'); // 50MB
      platform.setProperty('demuxer-readahead-secs', '60'); // Buffer 60 seconds ahead
      platform.setProperty('cache', 'yes');
      platform.setProperty('cache-secs', '60');
      platform.setProperty('hls-bitrate', 'min');
      
      // Network & Protocol Stability
      platform.setProperty('network-timeout', '20');
      platform.setProperty('stream-buffer-size', '8192000'); // 8MB
      platform.setProperty('http-header-fields', 'Referer: https://www.google.com');

    } catch (e) {
      debugPrint("Error setting mpv properties: $e");
    }

    // Listen for buffering state to show loading indicator
    _player.stream.buffering.listen((buffering) {
      if (mounted) {
        setState(() {
          _isBuffering = buffering;
        });
      }
    });

    _player.stream.error.listen((event) {
      debugPrint("MediaKit Error: $event");
    });

    // Listen for tracks - we don't force one initially to allow Auto (ABR) to work
    // HLS (m3u8) works best with Auto to avoid buffering.
    _player.stream.tracks.listen((tracks) {
      if (tracks.video.isNotEmpty) {
        debugPrint("Available video tracks: ${tracks.video.length}");
      }
    });

    await _player.open(Media(widget.stream.streamUrl));
    
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  void _showQualityMenu() {
    if (!_isInitialized) return;

    final videoTracks = _player.state.tracks.video;
    final currentTrack = _player.state.track.video;

    // Filter out 'no' and 'auto' for the list, and sort by resolution if possible
    final tracks = videoTracks.where((t) => t.id != 'no' && t.id != 'auto').toList();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Set Video Quality",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Text(
              "Lower quality reduces buffering",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 10),
            const Divider(color: Colors.white12),
            // Auto option
            ListTile(
              leading: Icon(Icons.speed, 
                  color: currentTrack.id == 'auto' ? Colors.blue : Colors.white70),
              title: const Text("Auto (Adaptive)", style: TextStyle(color: Colors.white)),
              subtitle: const Text("Adjusts based on internet speed", style: TextStyle(color: Colors.grey, fontSize: 11)),
              trailing: currentTrack.id == 'auto' ? const Icon(Icons.check, color: Colors.blue) : null,
              onTap: () {
                _player.setVideoTrack(VideoTrack.auto());
                Navigator.pop(context);
              },
            ),
            const Divider(color: Colors.white10),
            // Available tracks list
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: tracks.length,
                itemBuilder: (context, index) {
                  final track = tracks[index];
                  final isSelected = currentTrack.id == track.id;
                  String title = track.title ?? "Quality ${track.id}";
                  
                  // Clean up title and add indicators
                  String resolution = "";
                  if (title.contains("1080")) resolution = "1080p (Full HD)";
                  else if (title.contains("720")) resolution = "720p (HD)";
                  else if (title.contains("480")) resolution = "480p (SD)";
                  else if (title.contains("360")) resolution = "360p (Low)";
                  else if (title.contains("240")) resolution = "240p (Very Low)";
                  else resolution = title;

                  return ListTile(
                    leading: Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected ? Colors.green : Colors.white70,
                    ),
                    title: Text(resolution, style: TextStyle(
                      color: isSelected ? Colors.green : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    )),
                    subtitle: index == tracks.length - 1 ? const Text("Uses less data", style: TextStyle(fontSize: 10, color: Colors.grey)) : null,
                    onTap: () {
                      _player.setVideoTrack(track);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    AdService.setPlaybackActive(false);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (!_isYoutube && !_isWebView) {
      _player.dispose();
    }
    _youtubeController?.dispose();
    _floating.cancelOnLeavePiP();

    // Decrement viewer count
    AppFirebaseService().decrementViewerCount(widget.stream.id);
    
    super.dispose();
  }

  Future<void> _enablePip() async {
    final canUsePip = await _floating.isPipAvailable;
    if (canUsePip) {
      await _floating.enable(const ImmediatePiP(aspectRatio: Rational.landscape()));
    }
  }

  void _toggleFullscreen() {
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    if (isPortrait) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

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
          ? Stack(
              alignment: Alignment.center,
              children: [
                Video(
                  controller: _controller,
                  controls: MaterialVideoControls,
                ),
                if (_isBuffering)
                  const CircularProgressIndicator(color: Colors.white),
              ],
            )
          : CircularProgressIndicator(color: colorScheme.primary);
    }

    // Wrap player with branding logo and quality button
    final brandedPlayer = Stack(
      children: [
        Center(child: playerWidget),
        // Quality Settings Button (Floating on player)
        if (!_isYoutube && !_isWebView && _isInitialized)
          Positioned(
            top: 10,
            left: 10,
            child: SafeArea(
              child: Row(
                children: [
                  Material(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(30),
                    child: IconButton(
                      icon: const Icon(Icons.settings_suggest_outlined, color: Colors.white, size: 20),
                      onPressed: _showQualityMenu,
                      tooltip: 'Change Quality',
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(30),
                    child: IconButton(
                      icon: Icon(
                        isPortrait ? Icons.fullscreen : Icons.fullscreen_exit,
                        color: Colors.blueAccent,
                        size: 20,
                      ),
                      onPressed: _toggleFullscreen,
                      tooltip: 'Fullscreen',
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (!_isWebView)
          Positioned(
            top: 20,
            right: 20,
            child: SafeArea(
              child: Opacity(
                opacity: 0.5,
                child: Image.asset(
                  'assets/images/icon.png',
                  width: 90,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
      ],
    );

    return PiPSwitcher(
      childWhenDisabled: Scaffold(
        backgroundColor: Colors.black,
        appBar: isPortrait
            ? AppBar(
                backgroundColor: Colors.transparent,
                title: Text(widget.stream.title,
                    style: TextStyle(fontSize: 16, color: colorScheme.onSurface)),
                iconTheme: IconThemeData(color: colorScheme.onSurface),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share_rounded, color: Colors.blueAccent),
                    onPressed: () {
                      Share.share(
                        'Watching ${widget.stream.title} on SponT TV!\nDownload SponT TV for HD Live Sports & TV Channels: https://play.google.com/store/apps/details?id=com.hasib.sponttv',
                      );
                    },
                    tooltip: 'Share',
                  ),
                  IconButton(
                    icon: const Icon(Icons.feedback_outlined, color: Colors.orangeAccent),
                    onPressed: () async {
                      final String subject = Uri.encodeComponent("Report: ${widget.stream.title}");
                      final String body = Uri.encodeComponent("Hi, I am facing issues with ${widget.stream.title}. Please check.");
                      final Uri emailLaunchUri = Uri.parse("mailto:hasibakon74@gmail.com?subject=$subject&body=$body");
                      
                      try {
                        if (await canLaunchUrl(emailLaunchUri)) {
                          await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
                        } else {
                          // Fallback if canLaunchUrl fails
                          await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not open email app. Please email hasibakon74@gmail.com')),
                          );
                        }
                      }
                    },
                    tooltip: 'Report Issue',
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.greenAccent),
                    onPressed: () {
                      setState(() => _isInitialized = false);
                      if (!_isYoutube && !_isWebView) _player.dispose();
                      _checkUrlType();
                    },
                    tooltip: 'Refresh',
                  ),
                  IconButton(
                    icon: const Icon(Icons.picture_in_picture_alt, color: Colors.red,),
                    onPressed: _enablePip,
                  ),
                ],
              )
            : null,
        body: SafeArea(child: Center(child: brandedPlayer)),
      ),
      childWhenEnabled: brandedPlayer    );
  }
}

