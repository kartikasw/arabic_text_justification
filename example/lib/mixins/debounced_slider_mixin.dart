import 'dart:async';

import 'package:flutter/widgets.dart';

class DebouncedValue<T> {
  DebouncedValue(
    T initial, {
    required this.onChange,
    this.delay = const Duration(milliseconds: 150),
  })  : _current = initial,
        _rendered = initial;

  final VoidCallback onChange;
  final Duration delay;

  T _current;
  T _rendered;
  Timer? _timer;

  T get current => _current;

  T get rendered => _rendered;

  void set(T value) {
    _current = value;
    onChange();
    _timer?.cancel();
    _timer = Timer(delay, () {
      _rendered = value;
      onChange();
    });
  }

  void dispose() {
    _timer?.cancel();
  }
}

mixin DebouncedSliderMixin<T extends StatefulWidget> on State<T> {
  double _value = 20;
  double _renderedValue = 20;
  Timer? _debounce;

  @protected
  double get initialSliderValue => 20;

  @protected
  Duration get sliderDebounce => const Duration(milliseconds: 150);

  double get sliderValue => _value;

  double get renderedValue => _renderedValue;

  @override
  void initState() {
    super.initState();
    _value = initialSliderValue;
    _renderedValue = initialSliderValue;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void onSliderChanged(double v) {
    setState(() => _value = v);
    _debounce?.cancel();
    _debounce = Timer(sliderDebounce, () {
      if (mounted) setState(() => _renderedValue = v);
    });
  }
}
