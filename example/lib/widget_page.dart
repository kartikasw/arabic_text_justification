import 'dart:async';

import 'package:flutter/material.dart';
import 'package:arabic_text_justification/arabic_text_justification.dart';

import 'constants/constants.dart';
import 'main.dart';
import 'mixins/ayah_selection_mixin.dart';
import 'widgets/scrollable_page.dart';
import 'widgets/slider_header.dart';

const _scrollPadding = EdgeInsets.fromLTRB(8, 12, 8, 0);

class WidgetPage extends StatefulWidget {
  const WidgetPage({super.key});

  @override
  State<WidgetPage> createState() => _WidgetPageState();
}

class _WidgetPageState extends State<WidgetPage>
    with AyahSelectionMixin<WidgetPage>, TickerProviderStateMixin<WidgetPage> {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  // Sub-page 1 — line height slider.
  double _height = 38;
  double _renderedHeight = 38;
  Timer? _heightDebounce;

  // Sub-page 2 — font size slider.
  double _fontSize = 20;
  double _renderedFontSize = 20;
  Timer? _fontDebounce;

  @override
  void dispose() {
    _tabs.dispose();
    _heightDebounce?.cancel();
    _fontDebounce?.cancel();
    super.dispose();
  }

  void _onHeightChanged(double v) {
    setState(() => _height = v);
    _heightDebounce?.cancel();
    _heightDebounce = Timer(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _renderedHeight = v);
    });
  }

  void _onFontSizeChanged(double v) {
    setState(() => _fontSize = v);
    _fontDebounce?.cancel();
    _fontDebounce = Timer(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _renderedFontSize = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabs,
          labelColor: const Color(0xFF2E7D32),
          indicatorColor: const Color(0xFF2E7D32),
          tabs: const [
            Tab(text: 'Line height'),
            Tab(text: 'Font size'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _buildHeightTab(),
              _buildFontSizeTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeightTab() {
    return ScrollablePage(
      padding: _scrollPadding,
      header: SliderHeader(
        label: 'Line height',
        unit: 'px',
        value: _height,
        min: 20,
        max: 120,
        onChanged: _onHeightChanged,
        selectedAyah: selectedAyah,
        selectedWord: selectedWord,
      ),
      child: Column(
        children: [
          for (int i = 0; i < page3Lines.length; i++)
            _buildLine(i, height: _renderedHeight),
        ],
      ),
    );
  }

  Widget _buildFontSizeTab() {
    return ScrollablePage(
      padding: _scrollPadding,
      header: SliderHeader(
        label: 'Font size',
        value: _fontSize,
        min: 8,
        max: 64,
        onChanged: _onFontSizeChanged,
        selectedAyah: selectedAyah,
        selectedWord: selectedWord,
      ),
      child: Column(
        children: [
          for (int i = 0; i < page3Lines.length; i++)
            _buildLine(i, fontSize: _renderedFontSize),
        ],
      ),
    );
  }

  Widget _buildLine(int i, {double? fontSize, double? height}) {
    final isBasmallah = i == 0;
    return JustifiedArabicLine(
      words: page3Lines[i].words,
      justify: page3Lines[i].justify,
      fontSize: fontSize,
      height: height,
      padding: const EdgeInsets.symmetric(vertical: 2),
      marker: isBasmallah ? null : ayahMarker,
      highlightedWordIndices: isBasmallah ? null : highlightsFor(i),
      onWordTap: isBasmallah ? null : (idx, w) => onWordTap(i, idx, w),
      onMarkerTap: isBasmallah ? null : (idx, w) => onMarkerTap(i, idx, w),
    );
  }
}
