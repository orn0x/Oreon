<!-- 
Android AndroidManifest.xml Configuration for LAN Module

This file shows the required permissions and configuration for the LAN module
to work on Android. These should be added to your main AndroidManifest.xml

Location: android/app/src/main/AndroidManifest.xml
-->

<!-- Required Permissions -->
<!--
Add these inside the <manifest> tag, before the <application> tag:
-->

<uses-permission android:name="android.permission.INTERNET" />
<!-- Required for TCP server and client connections -->

<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<!-- Required to check if WiFi is connected and get WiFi information -->

<uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE" />
<!-- Required for mDNS discovery and advertisement -->

<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<!-- Required to check network state -->

<!--
Optional: If targeting Android 12+, also add:
<uses-permission android:name="android.permission.NEARBY_WIFI_DEVICES" />
-->

<!--
Application Configuration:

If not already present, add this to your <application> tag to ensure
proper mDNS functionality:

<application
    ...
    android:usesCleartextTraffic="true"
    ...
>
-->

<!-- 
Multicast Lock Setup:

The LAN module automatically handles multicast lock in Kotlin.
On Android 7+, multicast lock is automatically acquired when mDNS discovery starts
and released when it stops.

The implementation is in:
lib/lan_module/platform/android/mdns_impl.dart
and
android/app/src/main/kotlin/com/oreon/polygone_app/MdnsNativeImpl.kt
-->
