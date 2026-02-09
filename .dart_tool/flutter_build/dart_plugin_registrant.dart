//
// Generated file. Do not edit.
// This file is generated from template in file `flutter_tools/lib/src/flutter_plugins.dart`.
//

// @dart = 3.9

import 'dart:io'; // flutter_ignore: dart_io_import.
import 'package:flutter_blue_plus_android/flutter_blue_plus_android.dart' as flutter_blue_plus_android;
import 'package:flutter_image_compress_common/flutter_image_compress_common.dart' as flutter_image_compress_common;
import 'package:image_picker_android/image_picker_android.dart' as image_picker_android;
import 'package:shared_preferences_android/shared_preferences_android.dart' as shared_preferences_android;
import 'package:sqflite_android/sqflite_android.dart' as sqflite_android;
import 'package:flutter_blue_plus_darwin/flutter_blue_plus_darwin.dart' as flutter_blue_plus_darwin;
import 'package:flutter_image_compress_common/flutter_image_compress_common.dart' as flutter_image_compress_common;
import 'package:image_picker_ios/image_picker_ios.dart' as image_picker_ios;
import 'package:shared_preferences_foundation/shared_preferences_foundation.dart' as shared_preferences_foundation;
import 'package:sqflite_darwin/sqflite_darwin.dart' as sqflite_darwin;
import 'package:file_selector_linux/file_selector_linux.dart' as file_selector_linux;
import 'package:flutter_blue_plus_linux/flutter_blue_plus_linux.dart' as flutter_blue_plus_linux;
import 'package:image_picker_linux/image_picker_linux.dart' as image_picker_linux;
import 'package:network_info_plus/network_info_plus.dart' as network_info_plus;
import 'package:path_provider_linux/path_provider_linux.dart' as path_provider_linux;
import 'package:shared_preferences_linux/shared_preferences_linux.dart' as shared_preferences_linux;
import 'package:file_selector_macos/file_selector_macos.dart' as file_selector_macos;
import 'package:flutter_blue_plus_darwin/flutter_blue_plus_darwin.dart' as flutter_blue_plus_darwin;
import 'package:flutter_image_compress_macos/flutter_image_compress_macos.dart' as flutter_image_compress_macos;
import 'package:image_picker_macos/image_picker_macos.dart' as image_picker_macos;
import 'package:shared_preferences_foundation/shared_preferences_foundation.dart' as shared_preferences_foundation;
import 'package:sqflite_darwin/sqflite_darwin.dart' as sqflite_darwin;
import 'package:file_selector_windows/file_selector_windows.dart' as file_selector_windows;
import 'package:flutter_blue_plus_winrt/flutter_blue_plus_winrt.dart' as flutter_blue_plus_winrt;
import 'package:image_picker_windows/image_picker_windows.dart' as image_picker_windows;
import 'package:network_info_plus/network_info_plus.dart' as network_info_plus;
import 'package:path_provider_windows/path_provider_windows.dart' as path_provider_windows;
import 'package:shared_preferences_windows/shared_preferences_windows.dart' as shared_preferences_windows;

@pragma('vm:entry-point')
class _PluginRegistrant {

  @pragma('vm:entry-point')
  static void register() {
    if (Platform.isAndroid) {
      try {
        flutter_blue_plus_android.FlutterBluePlusAndroid.registerWith();
      } catch (err) {
        print(
          '`flutter_blue_plus_android` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        flutter_image_compress_common.FlutterImageCompressCommon.registerWith();
      } catch (err) {
        print(
          '`flutter_image_compress_common` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        image_picker_android.ImagePickerAndroid.registerWith();
      } catch (err) {
        print(
          '`image_picker_android` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        shared_preferences_android.SharedPreferencesAndroid.registerWith();
      } catch (err) {
        print(
          '`shared_preferences_android` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        sqflite_android.SqfliteAndroid.registerWith();
      } catch (err) {
        print(
          '`sqflite_android` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

    } else if (Platform.isIOS) {
      try {
        flutter_blue_plus_darwin.FlutterBluePlusDarwin.registerWith();
      } catch (err) {
        print(
          '`flutter_blue_plus_darwin` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        flutter_image_compress_common.FlutterImageCompressCommon.registerWith();
      } catch (err) {
        print(
          '`flutter_image_compress_common` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        image_picker_ios.ImagePickerIOS.registerWith();
      } catch (err) {
        print(
          '`image_picker_ios` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        shared_preferences_foundation.SharedPreferencesFoundation.registerWith();
      } catch (err) {
        print(
          '`shared_preferences_foundation` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        sqflite_darwin.SqfliteDarwin.registerWith();
      } catch (err) {
        print(
          '`sqflite_darwin` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

    } else if (Platform.isLinux) {
      try {
        file_selector_linux.FileSelectorLinux.registerWith();
      } catch (err) {
        print(
          '`file_selector_linux` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        flutter_blue_plus_linux.FlutterBluePlusLinux.registerWith();
      } catch (err) {
        print(
          '`flutter_blue_plus_linux` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        image_picker_linux.ImagePickerLinux.registerWith();
      } catch (err) {
        print(
          '`image_picker_linux` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        network_info_plus.NetworkInfoPlusLinuxPlugin.registerWith();
      } catch (err) {
        print(
          '`network_info_plus` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        path_provider_linux.PathProviderLinux.registerWith();
      } catch (err) {
        print(
          '`path_provider_linux` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        shared_preferences_linux.SharedPreferencesLinux.registerWith();
      } catch (err) {
        print(
          '`shared_preferences_linux` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

    } else if (Platform.isMacOS) {
      try {
        file_selector_macos.FileSelectorMacOS.registerWith();
      } catch (err) {
        print(
          '`file_selector_macos` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        flutter_blue_plus_darwin.FlutterBluePlusDarwin.registerWith();
      } catch (err) {
        print(
          '`flutter_blue_plus_darwin` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        flutter_image_compress_macos.FlutterImageCompressMacos.registerWith();
      } catch (err) {
        print(
          '`flutter_image_compress_macos` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        image_picker_macos.ImagePickerMacOS.registerWith();
      } catch (err) {
        print(
          '`image_picker_macos` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        shared_preferences_foundation.SharedPreferencesFoundation.registerWith();
      } catch (err) {
        print(
          '`shared_preferences_foundation` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        sqflite_darwin.SqfliteDarwin.registerWith();
      } catch (err) {
        print(
          '`sqflite_darwin` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

    } else if (Platform.isWindows) {
      try {
        file_selector_windows.FileSelectorWindows.registerWith();
      } catch (err) {
        print(
          '`file_selector_windows` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        flutter_blue_plus_winrt.FlutterBluePlusWinrt.registerWith();
      } catch (err) {
        print(
          '`flutter_blue_plus_winrt` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        image_picker_windows.ImagePickerWindows.registerWith();
      } catch (err) {
        print(
          '`image_picker_windows` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        network_info_plus.NetworkInfoPlusWindowsPlugin.registerWith();
      } catch (err) {
        print(
          '`network_info_plus` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        path_provider_windows.PathProviderWindows.registerWith();
      } catch (err) {
        print(
          '`path_provider_windows` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

      try {
        shared_preferences_windows.SharedPreferencesWindows.registerWith();
      } catch (err) {
        print(
          '`shared_preferences_windows` threw an error: $err. '
          'The app may not function as expected until you remove this plugin from pubspec.yaml'
        );
      }

    }
  }
}
