// Flutter web plugin registrant file.
//
// Generated file. Do not edit.
//

// @dart = 2.13
// ignore_for_file: type=lint

import 'package:flutter_blue_plus_web/flutter_blue_plus_web.dart';
import 'package:flutter_image_compress_web/flutter_image_compress_web.dart';
import 'package:image_picker_for_web/image_picker_for_web.dart';
import 'package:network_info_plus/src/network_info_plus_web.dart';
import 'package:permission_handler_html/permission_handler_html.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

void registerPlugins([final Registrar? pluginRegistrar]) {
  final Registrar registrar = pluginRegistrar ?? webPluginRegistrar;
  FlutterBluePlusWeb.registerWith(registrar);
  FlutterImageCompressWeb.registerWith(registrar);
  ImagePickerPlugin.registerWith(registrar);
  NetworkInfoPlusWebPlugin.registerWith(registrar);
  WebPermissionHandler.registerWith(registrar);
  SharedPreferencesPlugin.registerWith(registrar);
  registrar.registerMessageHandler();
}
