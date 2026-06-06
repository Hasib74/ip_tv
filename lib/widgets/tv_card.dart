import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/stream_model.dart';
import '../screens/player_screen.dart';

class TvCard extends StatelessWidget {
  final StreamModel stream;

  const TvCard({super.key, required this.stream});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PlayerScreen(stream: stream)),
      ),
      child: Hero(
        tag: stream.id,
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.outline.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // ── Full card logo area ──
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          cs.primaryContainer.withOpacity(0.18),
                          cs.surface,
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Subtle grid/scanline texture ──
                Positioned.fill(
                  child: CustomPaint(painter: _GridPainter(cs.primary.withOpacity(0.04))),
                ),

                // ── Main content ──
                Column(
                  children: [
                    // Logo — takes most of the card
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
                        child: CachedNetworkImage(
                          imageUrl: stream.team1Logo,
                          fit: BoxFit.contain,
                          placeholder: (_, __) => Center(
                            child: Icon(
                              Icons.tv_rounded,
                              color: cs.primary.withOpacity(0.25),
                              size: 36,
                            ),
                          ),
                          errorWidget: (_, __, ___) => Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: cs.onSurface.withOpacity(0.15),
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── Channel name bar ──
                    Expanded(
                      flex: 2,
                      child: Container(
                        width: double.infinity,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: cs.primary.withOpacity(0.07),
                          border: Border(
                            top: BorderSide(
                              color: cs.primary.withOpacity(0.12),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Text(
                          stream.title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // ── LIVE badge top-right ──
                Positioned(
                  top: 8,
                  right: 8,
                  child: _LiveBadge(cs: cs),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── LIVE badge ──────────────────────────────────────────────────────────────
class _LiveBadge extends StatefulWidget {
  final ColorScheme cs;
  const _LiveBadge({required this.cs});

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
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
    _pulse = Tween<double>(begin: 0.4, end: 1.0).animate(
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
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(_pulse.value),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 3),
          const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Subtle scanline grid painter ────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;
    const step = 18.0;
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.color != color;
}