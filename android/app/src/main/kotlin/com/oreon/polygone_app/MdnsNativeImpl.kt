// MdnsNativeImpl.kt
// 
// Android native implementation using NSD (Network Service Discovery) API
// Handles service advertisement and discovery via mDNS/Bonjour
// 
// Location: android/app/src/main/kotlin/com/oreon/polygone_app/MdnsNativeImpl.kt

package com.oreon.polygone_app

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Android native implementation for mDNS service discovery
 * 
 * Responsibilities:
 * - Service advertisement via NsdManager.registerService()
 * - Service discovery via NsdManager.discoverServices()
 * - Multicast lock management for all-device discovery
 * - Callback routing to Flutter via MethodChannel
 */
class MdnsNativeImpl(private val context: Context, private val flutterEngine: FlutterEngine) {

    companion object {
        const val CHANNEL = "com.oreon.polygone_app/mdns"
        const val SERVICE_TYPE = "_oreonchat._tcp"
    }

    private val nsdManager = context.getSystemService(Context.NSD_SERVICE) as NsdManager
    private val wifiManager = context.getApplicationContext()
        .getSystemService(Context.WIFI_SERVICE) as WifiManager
    
    private var multicastLock: WifiManager.MulticastLock? = null
    private var registrationListener: NsdManager.RegistrationListener? = null
    private var discoveryListener: NsdManager.DiscoveryListener? = null
    
    private var registeredServiceName: String? = null
    private val resolvedServices = mutableMapOf<String, ServiceInfo>()

    private data class ServiceInfo(
        val name: String,
        val address: String,
        val port: Int
    )

    /**
     * Sets up the method channel for Dart communication
     */
    fun setupChannel() {
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "mdns.advertise" -> {
                        val serviceName = call.argument<String>("serviceName")
                        val serviceType = call.argument<String>("serviceType")
                        val port = call.argument<Int>("port")
                        
                        if (serviceName != null && serviceType != null && port != null) {
                            startAdvertisement(serviceName, serviceType, port)
                            result.success(null)
                        } else {
                            result.error("INVALID_ARGS", "Missing required arguments", null)
                        }
                    }
                    "mdns.discover" -> {
                        val serviceType = call.argument<String>("serviceType")
                        if (serviceType != null) {
                            startDiscovery(serviceType)
                            result.success(null)
                        } else {
                            result.error("INVALID_ARGS", "Missing serviceType", null)
                        }
                    }
                    "mdns.stop" -> {
                        stopMdns()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("ERROR", e.message, null)
            }
        }
    }

    /**
     * Starts service advertisement
     * 
     * Creates NsdServiceInfo and registers with NsdManager.
     * Acquires multicast lock for reliable discovery.
     */
    private fun startAdvertisement(serviceName: String, serviceType: String, port: Int) {
        // Create service info
        val serviceInfo = NsdServiceInfo().apply {
            this.serviceName = serviceName
            this.serviceType = serviceType
            this.port = port
        }

        // Acquire multicast lock
        acquireMulticastLock()

        // Create registration listener
        registrationListener = object : NsdManager.RegistrationListener {
            override fun onServiceRegistered(nsdServiceInfo: NsdServiceInfo) {
                registeredServiceName = nsdServiceInfo.serviceName
                sendCallbackToFlutter("onRegistered", mapOf(
                    "serviceName" to nsdServiceInfo.serviceName
                ))
            }

            override fun onRegistrationFailed(nsdServiceInfo: NsdServiceInfo, errorCode: Int) {
                sendCallbackToFlutter("onRegistrationFailed", mapOf(
                    "errorCode" to errorCode
                ))
            }

            override fun onServiceUnregistered(nsdServiceInfo: NsdServiceInfo) {
                registeredServiceName = null
                sendCallbackToFlutter("onUnregistered", emptyMap())
            }

            override fun onUnregistrationFailed(nsdServiceInfo: NsdServiceInfo, errorCode: Int) {
                sendCallbackToFlutter("onUnregistrationFailed", mapOf(
                    "errorCode" to errorCode
                ))
            }
        }

        // Register the service
        nsdManager.registerService(serviceInfo, NsdManager.PROTOCOL_DNS_SD, registrationListener)
    }

    /**
     * Starts service discovery
     * 
     * Creates DiscoveryListener and searches for services of the specified type.
     * When services are found, automatically resolves them to get IP addresses.
     */
    private fun startDiscovery(serviceType: String) {
        // Acquire multicast lock
        acquireMulticastLock()

        // Create discovery listener
        discoveryListener = object : NsdManager.DiscoveryListener {
            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
                sendCallbackToFlutter("onDiscoveryStartFailed", mapOf(
                    "errorCode" to errorCode
                ))
            }

            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {
                sendCallbackToFlutter("onDiscoveryStopFailed", mapOf(
                    "errorCode" to errorCode
                ))
            }

            override fun onServiceFound(nsdServiceInfo: NsdServiceInfo) {
                // Resolve the discovered service to get address and port
                if (!nsdServiceInfo.serviceName.equals(registeredServiceName, ignoreCase = true)) {
                    nsdManager.resolveService(nsdServiceInfo, object : NsdManager.ResolveListener {
                        override fun onResolveFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {
                            sendCallbackToFlutter("onResolveFailed", mapOf(
                                "serviceName" to serviceInfo.serviceName,
                                "errorCode" to errorCode
                            ))
                        }

                        override fun onServiceResolved(nsdServiceInfo: NsdServiceInfo) {
                            val address = nsdServiceInfo.host?.hostAddress ?: return
                            val port = nsdServiceInfo.port
                            val serviceName = nsdServiceInfo.serviceName

                            resolvedServices[serviceName] = ServiceInfo(serviceName, address, port)

                            // Send callback to Flutter
                            sendCallbackToFlutter("onServiceDiscovered", mapOf(
                                "serviceName" to serviceName,
                                "address" to address,
                                "port" to port
                            ))
                        }
                    })
                }
            }

            override fun onServiceLost(nsdServiceInfo: NsdServiceInfo) {
                val serviceName = nsdServiceInfo.serviceName
                resolvedServices.remove(serviceName)

                sendCallbackToFlutter("onServiceLost", mapOf(
                    "serviceName" to serviceName
                ))
            }
        }

        // Start discovery
        nsdManager.discoverServices(serviceType, NsdManager.PROTOCOL_DNS_SD, discoveryListener)
    }

    /**
     * Stops all mDNS operations
     * 
     * Unregisters service, stops discovery, and releases multicast lock.
     */
    private fun stopMdns() {
        try {
            // Unregister service
            if (registrationListener != null) {
                nsdManager.unregisterService(registrationListener)
                registrationListener = null
            }

            // Stop discovery
            if (discoveryListener != null) {
                nsdManager.stopServiceDiscovery(discoveryListener)
                discoveryListener = null
            }

            // Clear resolved services
            resolvedServices.clear()

            // Release multicast lock
            releaseMulticastLock()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    /**
     * Acquires multicast lock for mDNS operations
     * 
     * Multicast lock is required on Android 7+ for reliable mDNS discovery.
     * Without it, devices may not receive multicast packets.
     */
    private fun acquireMulticastLock() {
        if (multicastLock == null) {
            multicastLock = wifiManager.createMulticastLock("oreon_mdns")
            multicastLock?.acquire()
        }
    }

    /**
     * Releases the multicast lock
     */
    private fun releaseMulticastLock() {
        multicastLock?.release()
        multicastLock = null
    }

    /**
     * Sends callback to Flutter via method channel
     */
    private fun sendCallbackToFlutter(method: String, arguments: Map<String, Any?>) {
        try {
            val channel = MethodChannel(
                com.oreon.polygone_app.MainActivity.flutterEngineRef?.dartExecutor?.binaryMessenger,
                CHANNEL
            )
            channel.invokeMethod(method, arguments)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}

/**
 * Integration in MainActivity.kt:
 * 
 * Add this to your MainActivity class:
 * 
 * companion object {
 *     var flutterEngineRef: FlutterEngine? = null
 * }
 * 
 * override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
 *     super.configureFlutterEngine(flutterEngine)
 *     flutterEngineRef = flutterEngine
 *     
 *     val mdnsImpl = MdnsNativeImpl(this, flutterEngine)
 *     mdnsImpl.setupChannel()
 * }
 * 
 * Required permissions in AndroidManifest.xml:
 * - android.permission.INTERNET
 * - android.permission.ACCESS_WIFI_STATE
 * - android.permission.CHANGE_WIFI_MULTICAST_STATE
 */
