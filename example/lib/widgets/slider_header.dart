import 'package:flutter/material.dart';

class SliderHeader extends StatelessWidget {
  final String label;
  final String unit;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final int? selectedAyah;
  final (int, int)? selectedWord;

  const SliderHeader({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.unit = '',
    this.selectedAyah,
    this.selectedWord,
  });

  @override
  Widget build(BuildContext context) {
    final display = '${value.round()}${unit.isEmpty ? '' : ' $unit'}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text('$label:'),
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              label: value.round().toString(),
              onChanged: onChanged,
            ),
          ),
          Text(
            display,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          const SizedBox(width: 8),
          if (selectedAyah != null)
            Text('Ayah: $selectedAyah',
                style: const TextStyle(color: Color(0xFF2E7D32))),
          if (selectedWord != null)
            Text('Word: ${selectedWord!.$1},${selectedWord!.$2}',
                style: const TextStyle(color: Color(0xFF2E7D32))),
        ],
      ),
    );
  }
}
