import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/stream_model.dart';
import '../screens/player_screen.dart';

class TvCard extends StatelessWidget {
  final StreamModel stream;

  const TvCard({super.key, required this.stream});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlayerScreen(stream: stream),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        colorScheme.primary.withOpacity(0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Hero(
                    tag: stream.id,
                    child: CachedNetworkImage(
                      imageUrl: stream.team1Logo,
                      placeholder: (context, url) => Icon(
                        Icons.tv_rounded,
                        color: colorScheme.onSurface.withOpacity(0.2),
                        size: 32,
                      ),
                      errorWidget: (context, url, error) => Icon(
                        Icons.broken_image_rounded,
                        color: colorScheme.onSurface.withOpacity(0.2),
                        size: 32,
                      ),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.08),
                  border: Border(
                    top: BorderSide(color: colorScheme.primary.withOpacity(0.1)),
                  ),
                ),
                child: Text(
                  stream.title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
