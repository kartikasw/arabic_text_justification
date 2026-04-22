import 'package:flutter/material.dart';

class LabeledSwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? leading;

  const LabeledSwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        spacing: 8,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (leading != null) leading!,
          Text(label),
          Transform.scale(
            scale: 0.75,
            child: Switch(
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              value: value,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
