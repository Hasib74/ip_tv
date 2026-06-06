import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/stream_model.dart';
import '../screens/player_screen.dart';

class StreamCard extends StatelessWidget {
  final StreamModel stream;

  const StreamCard({super.key, required this.stream});

  @override
  Widget build(BuildContext context) {
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
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2746),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.sports_motorsports, size: 16, color: Colors.redAccent),
                    const SizedBox(width: 4),
                    Text(
                      stream.title,
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text(
                  "${DateFormat('hh:mm a').format(stream.startTime)}  ${DateFormat('dd/MM/yyyy').format(stream.startTime)}",
                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTeam(stream.team1Name, stream.team1Logo),
                const Text(
                  "VS",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                _buildTeam(stream.team2Name, stream.team2Logo),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeam(String name, String logo) {
    return Column(
      children: [
        CachedNetworkImage(
          imageUrl: logo,
          height: 40,
          width: 40,
          placeholder: (context, url) => const Icon(Icons.image, color: Colors.white24),
          errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white24),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ],
    );
  }
}
