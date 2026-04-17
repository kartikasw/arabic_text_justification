import 'dart:async';

import 'package:flutter/material.dart';
import 'package:arabic_text_justification/arabic_text_justification.dart';

import 'main.dart';

class WidgetPage extends StatefulWidget {
  const WidgetPage({super.key});

  @override
  State<WidgetPage> createState() => _WidgetPageState();
}

class _WidgetPageState extends State<WidgetPage> {
  double _fontSize = 24;
  double _renderedFontSize = 24;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onFontSizeChanged(double v) {
    setState(() => _fontSize = v);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _renderedFontSize = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Text('Font size:'),
              Expanded(
                child: Slider(
                  value: _fontSize,
                  min: 8,
                  max: 64,
                  label: _fontSize.round().toString(),
                  onChanged: _onFontSizeChanged,
                ),
              ),
              Text(_fontSize.round().toString()),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final line in page3Lines)
                  JustifiedArabicLine(
                    words: line.words,
                    justify: line.justify,
                    fontSize: _renderedFontSize,
                    color: Colors.pink,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
