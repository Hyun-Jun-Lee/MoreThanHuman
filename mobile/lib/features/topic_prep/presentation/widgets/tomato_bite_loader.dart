import 'package:curitalk/core/widgets/app_loading_indicator.dart';
import 'package:flutter/material.dart';

/// 기존 주제 준비 화면의 로딩 위치를 공통 토마토 표시로 연결해요.
class TomatoBiteLoader extends StatelessWidget {
  const TomatoBiteLoader({required this.semanticLabel, super.key});

  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return AppLoadingIndicator(width: 160, semanticLabel: semanticLabel);
  }
}
