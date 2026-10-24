import 'dart:async';

import 'package:curitalk/core/copy/copy.dart';
import 'package:flutter/material.dart';

/// 가로로 나열된 토마토의 활성 단계를 순서대로 강조하는 공통 로딩 표시예요.
class AppLoadingIndicator extends StatefulWidget {
  const AppLoadingIndicator({this.width = 160, this.semanticLabel, super.key});

  final double width;
  final String? semanticLabel;

  static const List<String> _frames = <String>[
    'assets/images/loading/tomato_row_0.png',
    'assets/images/loading/tomato_row_1.png',
    'assets/images/loading/tomato_row_2.png',
    'assets/images/loading/tomato_row_3.png',
    'assets/images/loading/tomato_row_4.png',
  ];

  @override
  State<AppLoadingIndicator> createState() => _AppLoadingIndicatorState();
}

class _AppLoadingIndicatorState extends State<AppLoadingIndicator> {
  static const Duration _stepDuration = Duration(milliseconds: 420);
  static const double _aspectRatio = 500 / 112;

  Timer? _timer;
  int _frame = 0;
  bool _precached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precached) {
      _precached = true;
      for (final String path in AppLoadingIndicator._frames) {
        precacheImage(AssetImage(path), context);
      }
    }

    final bool animate =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (animate && _timer == null) {
      _timer = Timer.periodic(_stepDuration, (_) {
        if (!mounted) return;
        setState(() {
          _frame = (_frame + 1) % AppLoadingIndicator._frames.length;
        });
      });
    } else if (!animate) {
      _timer?.cancel();
      _timer = null;
      _frame = 0;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel ?? AppCopy.of(context).defaultLoadingLabel,
      child: SizedBox(
        width: widget.width,
        height: widget.width / _aspectRatio,
        child: Image.asset(
          AppLoadingIndicator._frames[_frame],
          fit: BoxFit.contain,
          gaplessPlayback: true,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
