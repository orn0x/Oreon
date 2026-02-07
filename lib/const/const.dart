class ConstApp {
  static const String appName = "Oreon";
  static const String appVersion = "1.0.0";
  String appIdentifier() {
    return "${appName}_v$appVersion";
  }
}