<!-- 
iOS Configuration for LAN Module

This document describes the required configuration for the LAN module
to work on iOS. These settings should be added to your Info.plist.

Location: ios/Runner/Info.plist
-->

<!--
1. Add Bonjour Service Types (NSBonjourServices)

In Info.plist, add the following inside the root <dict>:

<key>NSBonjourServices</key>
<array>
  <string>_oreonchat._tcp</string>
  <string>_oreonchat._udp</string>
</array>

This registers the Bonjour service types used by the LAN module.
iOS requires explicit service type registration for mDNS.
-->

<!--
2. Add Local Network Privacy Description (iOS 14.5+)

iOS 14.5+ requires apps to declare local network access intent.
Add this to Info.plist inside the root <dict>:

<key>NSLocalNetworkUsageDescription</key>
<string>Oreon needs access to your local network to discover and communicate with nearby devices for LAN chat functionality.</string>

This message is shown to users when they first use the local network access.
-->

<!--
3. Add Bonjour Usage Description (iOS 14.0+)

For clarity, add this to Info.plist:

<key>NSBonjourUsageDescription</key>
<string>Oreon uses Bonjour to discover nearby devices for chat on your local network.</string>

This provides additional context for users.
-->

<!--
4. Network Extension (Optional, for advanced scenarios)

If you need special network privileges, add:

<key>NSNetworkExtensionUsageDescription</key>
<string>Oreon needs network extension permissions for local network communication.</string>
-->

<!--
Additional iOS Notes:

1. ATS (App Transport Security):
   - Cleartext traffic on localhost is allowed by default
   - Traffic to local network IPs should work without ATS exemption
   - If needed, add to Info.plist:
   
   <key>NSAppTransportSecurity</key>
   <dict>
     <key>NSAllowsLocalNetworking</key>
     <true/>
   </dict>

2. Background Execution:
   - If you need the LAN module to work in background, add:
   
   <key>UIBackgroundModes</key>
   <array>
     <string>fetch</string>
     <string>processing</string>
   </array>

3. Bluetooth LE (if combining with BLE):
   - Add NSBluetoothPeripheralUsageDescription
   - Add NSBluetoothCentralUsageDescription

4. WiFi (already covered):
   - NSLocalNetworkUsageDescription covers WiFi access
   - NSBonjourServices covers Bonjour/mDNS
-->

<!--
Testing on iOS Simulator vs Device:

Simulator:
- mDNS discovery works for services advertised from other simulators
- Real devices won't be discoverable from simulator
- Recommended: Test on real devices for accurate behavior

Device:
- Requires same WiFi network
- Privacy prompts appear on first use
- Works with both local network and hotspot scenarios
-->

<!--
Implementation Files:

The iOS implementation is in:
lib/lan_module/platform/ios/mdns_impl.dart
ios/Runner/GeneratedPluginRegistrant.m (auto-generated)
-->
