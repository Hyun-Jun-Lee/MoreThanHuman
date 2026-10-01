import 'package:flutter/material.dart';

/// 탭이 유지되는 동안 각 목록의 스크롤과 활성 상태를 공유해요.
class MainTabScope extends InheritedWidget {
  const MainTabScope({
    required this.index,
    required this.controllers,
    required super.child,
    super.key,
  });

  /// 활성 목적지 인덱스예요. 루트 준비·대화 화면이 덮으면 -1이에요.
  final int index;
  final List<ScrollController> controllers;
  static MainTabScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MainTabScope>();
  @override
  bool updateShouldNotify(MainTabScope oldWidget) => index != oldWidget.index;
}
