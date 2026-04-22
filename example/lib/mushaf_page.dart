import 'package:arabic_text_justification/arabic_text_justification.dart';
import 'package:flutter/material.dart';

import 'constants/constants.dart';
import 'main.dart';

class MushafPage extends StatefulWidget {
  const MushafPage({super.key});

  @override
  State<MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<MushafPage> {
  static const _pageNumbers = [3, 5];

  final _controller = PageController();
  int _currentIndex = 0;

  List<PageLine> _dataFor(int pageNumber) {
    switch (pageNumber) {
      case 5:
        return page5Lines.isNotEmpty ? page5Lines : page3Lines;
      case 3:
      default:
        return page3Lines;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF5E6),
      appBar: AppBar(
        title: Text('Mushaf Page ${_pageNumbers[_currentIndex]}'),
        backgroundColor: appGreen,
        foregroundColor: Colors.white,
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: _pageNumbers.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (context, index) {
          final pageNumber = _pageNumbers[index];
          final lines = _dataFor(pageNumber);
          return _MushafPageView(pageNumber: pageNumber, lines: lines);
        },
      ),
    );
  }
}

class _MushafPageView extends StatelessWidget {
  final int pageNumber;
  final List<PageLine> lines;

  const _MushafPageView({required this.pageNumber, required this.lines});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          spacing: 8,
          children: [
            Expanded(
              child: pageNumber == 5
                  ? _buildWithLines()
                  : _buildWithBlock(),
            ),
            Text(
              '$pageNumber',
              style: const TextStyle(
                fontSize: 14,
                color: appGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWithBlock() {
    return JustifiedArabicBlock(
      lineSpacing: 2,
      lines: [
        for (final line in lines)
          JustifiedArabicLineSpec(
            words: line.words,
            justify: line.justify,
            alignment: line.justify ? null : Alignment.center,
          ),
      ],
    );
  }

  Widget _buildWithLines() {
    const lineSpacing = 2.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final n = lines.length;
        final available = constraints.maxHeight;
        final perLine = (available - (n - 1) * lineSpacing) / n - 1;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < n; i++) ...[
              if (i > 0) const SizedBox(height: lineSpacing),
              JustifiedArabicLine(
                words: lines[i].words,
                justify: lines[i].justify,
                height: perLine,
                alignment:
                    lines[i].justify ? null : Alignment.center,
              ),
            ],
          ],
        );
      },
    );
  }
}
