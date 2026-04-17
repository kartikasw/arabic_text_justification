import 'package:flutter/material.dart';

class ScrollablePage extends StatelessWidget {
  final Widget header;
  final List<Widget> extras;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const ScrollablePage({
    super.key,
    required this.header,
    required this.child,
    this.extras = const [],
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        header,
        ...extras,
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: padding,
            child: child,
          ),
        ),
      ],
    );
  }
}
