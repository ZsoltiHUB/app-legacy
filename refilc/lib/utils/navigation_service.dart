import 'package:flutter/material.dart';

class NavigationService {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  Future<dynamic> navigateTo(String routeName) {
    final state = navigatorKey.currentState;
    if (state == null) return Future.value();
    return state.pushNamed(routeName);
  }
}
