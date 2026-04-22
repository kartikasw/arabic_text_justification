import 'package:arabic_text_justification/arabic_text_justification.dart';
import 'package:flutter/material.dart';

import 'constants/constants.dart';
import 'constants/tajweed.dart';
import 'main.dart';
import 'mixins/debounced_slider_mixin.dart';
import 'mixins/playback_mixin.dart';
import 'widgets/labeled_switch_row.dart';
import 'widgets/playback_controls.dart';
import 'widgets/scrollable_page.dart';
import 'widgets/slider_header.dart';
import 'widgets/tajweed_legend.dart';

class BlockPage extends StatefulWidget {
  const BlockPage({super.key});

  @override
  State<BlockPage> createState() => _BlockPageState();
}

class _BlockPageState extends State<BlockPage>
    with TickerProviderStateMixin<BlockPage>, PlaybackMixin<BlockPage> {
  late final TabController _tabs = TabController(length: 4, vsync: this);

  // Block data — falls back to page 3 when page 5 is empty.
  @override
  List<PageLine> get dataLines =>
      page5Lines.isNotEmpty ? page5Lines : page3Lines;

  // Reveal tab state
  bool _showAll = false;

  // Tajweed tab state
  bool _tajweedOn = true;
  late final List<List<WordColorSpan>> _spansByLine =
      buildTajweedSpans(dataLines);

  // Size tab state
  bool _autoFit = false;
  late final _fontSize = DebouncedValue<double>(20, onChange: _markDirty);
  late final _lineSpacing = DebouncedValue<double>(4, onChange: _markDirty);

  void _markDirty() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabs.dispose();
    _fontSize.dispose();
    _lineSpacing.dispose();
    super.dispose();
  }

  AlignmentGeometry? _alignFor(PageLine line) =>
      line.justify ? null : Alignment.center;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabs,
          labelColor: appGreen,
          indicatorColor: appGreen,
          tabs: const [
            Tab(text: 'Size'),
            Tab(text: 'Progress'),
            Tab(text: 'Reveal'),
            Tab(text: 'Tajweed'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _buildSizeTab(),
              _buildProgressTab(),
              _buildRevealTab(),
              _buildTajweedTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressTab() {
    return ScrollablePage(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      header: PlaybackControls(
        position: position,
        total: total,
        isPlaying: isPlaying,
        onTogglePlay: togglePlay,
        onReset: reset,
        onSeek: seek,
      ),
      child: ValueListenableBuilder<Duration>(
        valueListenable: position,
        builder: (_, pos, __) {
          final states = statesAt(pos);
          return JustifiedArabicBlock(
            fontSize: 20,
            lineSpacing: 4,
            lines: [
              for (var i = 0; i < dataLines.length; i++)
                JustifiedArabicLineSpec(
                  words: dataLines[i].words,
                  justify: dataLines[i].justify,
                  alignment: _alignFor(dataLines[i]),
                  wordProgress: wholeGreyProgress(states[i]),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRevealTab() {
    return ScrollablePage(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      header: PlaybackControls(
        position: position,
        total: total,
        isPlaying: isPlaying,
        onTogglePlay: togglePlay,
        onReset: reset,
        onSeek: seek,
      ),
      extras: [
        LabeledSwitchRow(
          label: 'Show all words',
          value: _showAll,
          onChanged: (v) => setState(() => _showAll = v),
          leading: Icon(
            _showAll ? Icons.visibility : Icons.visibility_off,
            size: 20,
            color: appGreen,
          ),
        ),
      ],
      child: ValueListenableBuilder<Duration>(
        valueListenable: position,
        builder: (_, pos, __) {
          final states = statesAt(pos);
          return JustifiedArabicBlock(
            fontSize: 20,
            lineSpacing: 4,
            lines: [
              for (var i = 0; i < dataLines.length; i++)
                JustifiedArabicLineSpec(
                  words: dataLines[i].words,
                  justify: dataLines[i].justify,
                  alignment: _alignFor(dataLines[i]),
                  wordProgress: revealProgress(states[i], showAll: _showAll),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTajweedTab() {
    return ScrollablePage(
      padding: scrollablePagePadding,
      header: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: LabeledSwitchRow(
          label: 'Tajweed',
          value: _tajweedOn,
          onChanged: (v) => setState(() => _tajweedOn = v),
        ),
      ),
      extras: [
        if (_tajweedOn) const TajweedLegend(),
      ],
      child: JustifiedArabicBlock(
        fontSize: 20,
        lineSpacing: 4,
        lines: [
          for (var i = 0; i < dataLines.length; i++)
            JustifiedArabicLineSpec(
              words: dataLines[i].words,
              justify: dataLines[i].justify,
              alignment: _alignFor(dataLines[i]),
              colorSpans: _tajweedOn ? _spansByLine[i] : null,
            ),
        ],
      ),
    );
  }

  Widget _buildSizeTab() {
    return ScrollablePage(
      padding: scrollablePagePadding,
      header: SliderHeader(
        label: 'Font size',
        value: _fontSize.current,
        min: 8,
        max: 64,
        onChanged: _autoFit ? (_) {} : _fontSize.set,
      ),
      extras: [
        SliderHeader(
          label: 'Line spacing',
          unit: 'px',
          value: _lineSpacing.current,
          min: 0,
          max: 32,
          onChanged: _lineSpacing.set,
        ),
        LabeledSwitchRow(
          label: 'Auto-fit width',
          value: _autoFit,
          onChanged: (v) => setState(() => _autoFit = v),
        ),
      ],
      child: JustifiedArabicBlock(
        fontSize: _autoFit ? null : _fontSize.rendered,
        lineSpacing: _lineSpacing.rendered,
        lines: [
          for (var i = 0; i < dataLines.length; i++)
            JustifiedArabicLineSpec(
              words: dataLines[i].words,
              justify: dataLines[i].justify,
              alignment: _alignFor(dataLines[i]),
            ),
        ],
      ),
    );
  }
}
