import 'package:flutter/material.dart';

import '../constants/tajweed.dart';

class TajweedLegend extends StatelessWidget {
  const TajweedLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: [
          for (final rule in TajweedRule.values)
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: rule.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Text(
                  rule.label,
                  style: TextStyle(color: rule.color, fontSize: 14),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
