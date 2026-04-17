import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PlaybackControls extends StatelessWidget {
  final ValueListenable<Duration> position;
  final Duration total;
  final bool isPlaying;
  final VoidCallback onTogglePlay;
  final VoidCallback onReset;
  final ValueChanged<double> onSeek;

  const PlaybackControls({
    super.key,
    required this.position,
    required this.total,
    required this.isPlaying,
    required this.onTogglePlay,
    required this.onReset,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          ValueListenableBuilder<Duration>(
            valueListenable: position,
            builder: (_, pos, __) {
              final fraction = total.inMilliseconds == 0
                  ? 0.0
                  : pos.inMilliseconds / total.inMilliseconds;
              return Slider(
                value: fraction.clamp(0.0, 1.0),
                onChanged: onSeek,
              );
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filled(
                onPressed: onTogglePlay,
                icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                onPressed: onReset,
                icon: const Icon(Icons.stop),
              ),
              const SizedBox(width: 16),
              ValueListenableBuilder<Duration>(
                valueListenable: position,
                builder: (_, pos, __) => Text(
                  '${pos.inSeconds}s / ${total.inSeconds}s',
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
