import 'package:flutter/material.dart';
import 'package:arabic_text_justification/arabic_text_justification.dart';

import 'constants/constants.dart';
import 'main.dart';
import 'mixins/ayah_selection_mixin.dart';
import 'mixins/debounced_slider_mixin.dart';
import 'widgets/scrollable_page.dart';
import 'widgets/slider_header.dart';

class WidgetPage extends StatefulWidget {
  const WidgetPage({super.key});

  @override
  State<WidgetPage> createState() => _WidgetPageState();
}

class _WidgetPageState extends State<WidgetPage>
    with AyahSelectionMixin<WidgetPage>, TickerProviderStateMixin<WidgetPage> {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  // Sub-page 1 — line height slider.
  late final _height = DebouncedValue<double>(38, onChange: _markDirty);

  // Sub-page 2 — font size slider.
  late final _fontSize = DebouncedValue<double>(20, onChange: _markDirty);

  void _markDirty() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabs.dispose();
    _height.dispose();
    _fontSize.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabs,
          labelColor: appGreen,
          indicatorColor: appGreen,
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
      padding: scrollablePagePadding,
      header: SliderHeader(
        label: 'Line height',
        unit: 'px',
        value: _height.current,
        min: 20,
        max: 120,
        onChanged: _height.set,
        selectedAyah: selectedAyah,
        selectedWord: selectedWord,
      ),
      child: Column(
        children: [
          for (int i = 0; i < page3Lines.length; i++)
            _buildLine(i, height: _height.rendered),
        ],
      ),
    );
  }

  Widget _buildFontSizeTab() {
    return ScrollablePage(
      padding: scrollablePagePadding,
      header: SliderHeader(
        label: 'Font size',
        value: _fontSize.current,
        min: 8,
        max: 64,
        onChanged: _fontSize.set,
        selectedAyah: selectedAyah,
        selectedWord: selectedWord,
      ),
      child: Column(
        children: [
          for (int i = 0; i < page3Lines.length; i++)
            _buildLine(i, fontSize: _fontSize.rendered),
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
      padding: linePadding,
      marker: isBasmallah ? null : ayahMarker,
      highlightedWordIndices: isBasmallah ? null : highlightsFor(i),
      onWordTap: isBasmallah ? null : (idx, w) => onWordTap(i, idx, w),
      onMarkerTap: isBasmallah ? null : (idx, w) => onMarkerTap(i, idx, w),
    );
  }
}
