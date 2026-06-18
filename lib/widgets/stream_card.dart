import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/stream_model.dart';
import '../screens/player_screen.dart';

class StreamCard extends StatefulWidget {
  final StreamModel stream;

  const StreamCard({super.key, required this.stream});

  @override
  State<StreamCard> createState() => _StreamCardState();
}

class _StreamCardState extends State<StreamCard> {
  Timer? _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    if (widget.stream.isScheduled) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
        if (_now.isAfter(widget.stream.startTime)) {
          _timer?.cancel();
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _getCountdownText() {
    final difference = widget.stream.startTime.difference(_now);
    if (difference.isNegative) return "LIVE";

    final hours = difference.inHours.toString().padLeft(2, '0');
    final minutes = (difference.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (difference.inSeconds % 60).toString().padLeft(2, '0');

    return "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isStarted = !widget.stream.isScheduled || _now.isAfter(widget.stream.startTime);
    final countdownStr = widget.stream.isScheduled ? _getCountdownText() : "LIVE";

    return Focus(
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;

          return GestureDetector(
            onTap: () {
              if (isStarted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PlayerScreen(stream: widget.stream)),
                );
              } else {
                _showMatchInfoSheet(context, cs, countdownStr);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isFocused 
                      ? cs.primary 
                      : (isStarted ? cs.primary.withOpacity(0.3) : cs.outline.withOpacity(0.12)),
                  width: isFocused ? 2.5 : (isStarted ? 1.2 : 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isFocused ? cs.primary.withOpacity(0.3) : cs.shadow.withOpacity(0.08),
                    blurRadius: isFocused ? 20 : 14,
                    offset: isFocused ? const Offset(0, 8) : const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  children: [
                    // ── Header ──
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isFocused
                          ? cs.primary.withOpacity(0.15)
                          : (isStarted 
                              ? cs.primaryContainer.withOpacity(0.25)
                              : cs.surfaceVariant.withOpacity(0.3)),
                        border: Border(
                          bottom: BorderSide(color: cs.primary.withOpacity(0.08)),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Badge (LIVE or Countdown)
                          if (isStarted) 
                            _LivePill(cs: cs)
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                countdownStr,
                                style: TextStyle(
                                  color: cs.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          const SizedBox(width: 10),
                          // Title
                          Expanded(
                            child: Text(
                              widget.stream.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Time/Date removed as per user request
                        ],
                      ),
                    ),

                    // ── Teams / Banner ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                      child: widget.stream.displayStyle == 'simple'
                          ? Center(
                              child: Column(
                                children: [
                                  Container(
                                    width: 100,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: cs.surfaceVariant.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: cs.outline.withOpacity(0.12)),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: CachedNetworkImage(
                                        imageUrl: widget.stream.logo.isNotEmpty ? widget.stream.logo : widget.stream.team1Logo,
                                        fit: BoxFit.fill,
                                        placeholder: (_, __) => Icon(
                                          widget.stream.subtitle.toLowerCase().contains('sport')
                                              ? Icons.sports_soccer_rounded
                                              : Icons.tv_rounded,
                                          color: cs.onSurface.withOpacity(0.12),
                                          size: 40,
                                        ),
                                        errorWidget: (_, __, ___) => Icon(
                                          widget.stream.subtitle.toLowerCase().contains('sport')
                                              ? Icons.sports_soccer_rounded
                                              : Icons.tv_rounded,
                                          color: cs.onSurface.withOpacity(0.12),
                                          size: 40,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    widget.stream.title,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: cs.onSurface.withOpacity(0.9),
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "WATCH LIVE EVENT",
                                    style: TextStyle(
                                      color: cs.primary.withOpacity(0.7),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Row(
                              children: [
                                Expanded(child: _buildTeam(cs, widget.stream.team1Name, widget.stream.team1Logo)),
                                _buildVSBadge(cs, isStarted),
                                Expanded(child: _buildTeam(cs, widget.stream.team2Name, widget.stream.team2Logo)),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      ),
    );
  }

  void _showMatchInfoSheet(BuildContext context, ColorScheme cs, String initialCountdown) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          // Internal timer for the sheet
          return StreamBuilder(
            stream: Stream.periodic(const Duration(seconds: 1)),
            builder: (context, snapshot) {
              final currentCountdown = _getCountdownText();
              final isNowStarted = !widget.stream.isScheduled || DateTime.now().isAfter(widget.stream.startTime);

              if (isNowStarted) {
                // If match starts while sheet is open, we can auto-close or update UI
                Future.microtask(() => Navigator.pop(context));
              }

              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  border: Border.all(color: cs.primary.withOpacity(0.1)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    
                    Text(
                      "Upcoming Match",
                      style: TextStyle(
                        color: cs.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Match Title
                    Text(
                      widget.stream.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Visual VS Area
                    widget.stream.displayStyle == 'simple'
                        ? Center(
                            child: _buildSheetTeam(cs, widget.stream.title, widget.stream.logo.isNotEmpty ? widget.stream.logo : widget.stream.team1Logo),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildSheetTeam(cs, widget.stream.team1Name, widget.stream.team1Logo),
                              Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: cs.primary.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Text(
                                      "VS",
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              _buildSheetTeam(cs, widget.stream.team2Name, widget.stream.team2Logo),
                            ],
                          ),

                    const SizedBox(height: 40),
                    
                    // Info Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.access_time_rounded, color: cs.primary, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                "Starts in $currentCountdown",
                                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Match starts at ${DateFormat('MMM dd, hh:mm a').format(widget.stream.startTime)} GMT",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Close Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Got it, Notify me!",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              );
            }
          );
        },
      ),
    );
  }

  Widget _buildSheetTeam(ColorScheme cs, String name, String logo) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: CachedNetworkImage(
            imageUrl: logo,
            fit: BoxFit.fill,
            errorWidget: (_, __, ___) => const Icon(Icons.sports_soccer, color: Colors.white10, size: 40),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 90,
          child: Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildTeam(ColorScheme cs, String name, String logo) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cs.surfaceVariant.withOpacity(0.5),
            shape: BoxShape.circle,
            border: Border.all(color: cs.outline.withOpacity(0.12)),
          ),
          child: CachedNetworkImage(
            imageUrl: logo,
            fit: BoxFit.fill,
            placeholder: (_, __) => Icon(
              widget.stream.subtitle.toLowerCase().contains('sport')
                  ? Icons.sports_soccer_rounded
                  : Icons.tv_rounded,
              color: cs.onSurface.withOpacity(0.12),
              size: 32,
            ),
            errorWidget: (_, __, ___) => Icon(
              widget.stream.subtitle.toLowerCase().contains('sport')
                  ? Icons.sports_soccer_rounded
                  : Icons.tv_rounded,
              color: cs.onSurface.withOpacity(0.12),
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cs.onSurface.withOpacity(0.9),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildVSBadge(ColorScheme cs, bool isStarted) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isStarted ? [cs.primary, cs.secondary] : [Colors.grey.shade700, Colors.grey.shade900],
              ),
              shape: BoxShape.circle,
              boxShadow: isStarted ? [
                BoxShadow(
                  color: cs.primary.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ] : [],
            ),
            child: const Center(
              child: Text(
                'VS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('dd MMM').format(widget.stream.startTime),
            style: TextStyle(
              color: cs.onSurface.withOpacity(0.4),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated LIVE pill ───────────────────────────────────────────────────────
class _LivePill extends StatefulWidget {
  final ColorScheme cs;
  const _LivePill({required this.cs});

  @override
  State<_LivePill> createState() => _LivePillState();
}

class _LivePillState extends State<_LivePill>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.error.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cs.error.withOpacity(0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: cs.error.withOpacity(_pulse.value),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'LIVE',
            style: TextStyle(
              color: cs.error,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
