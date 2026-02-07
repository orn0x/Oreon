import 'dart:ui';

import 'package:flutter/material.dart';

class ConstApp {
  static const String appName = "Oreon";
  static const String appVersion = "1.0.0";
  String appIdentifier() {
    return "${appName}_v$appVersion";
  }
  static MaterialColor Wifi = Colors.green;
  static MaterialColor Bluetooth = Colors.blue;
  static MaterialColor Centralized = Colors.orange;
}