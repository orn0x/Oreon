package com.example.polygone_app

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.net.wifi.WifiManager
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MdnsNativeImpl(
    private val context: Context,
    private val flutterEngine: FlutterEngine
) {

    companion object {
        const val CHANNEL = "com.example.polygone_app/mdns"
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val nsdManager =
        context.getSystemService(Context.NSD_SERVICE) as NsdManager
    private val wifiManager =
        context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager

    private var multicastLock: WifiManager.MulticastLock? = null
    private var registrationListener: NsdManager.RegistrationListener? = null
    private var discoveryListener: NsdManager.DiscoveryListener? = null
    private var methodChannel: MethodChannel? = null

    private var registeredServiceName: String? = null
    private val resolvedServices = mutableMapOf<String, ServiceInfo>()

    private data class ServiceInfo(
        val name: String,
        val address: String,
        val port: Int
    )

    fun setupChannel() {
        methodChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        methodChannel?.setMethodCallHandler { call, result ->
            mainHandler.post {
                try {
                    when (call.method) {

                        "mdns.advertise" -> {
                            val name = call.argument<String>("serviceName")
                            val type = call.argument<String>("serviceType")
                            val port = call.argument<Int>("port")

                            if (name != null && type != null && port != null) {
                                startAdvertisement(name, type, port)
                                result.success(null)
                            } else {
                                result.error("INVALID_ARGS", "Missing args", null)
                            }
                        }

                        "mdns.discover" -> {
                            val type = call.argument<String>("serviceType")
                            if (type != null) {
                                startDiscovery(type)
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
    }

    // -------------------------
    // Advertisement
    // -------------------------

    private fun startAdvertisement(
        serviceName: String,
        serviceType: String,
        port: Int
    ) {
        mainHandler.post {

            acquireMulticastLock()

            val serviceInfo = NsdServiceInfo().apply {
                this.serviceName = serviceName
                this.serviceType = serviceType
                this.port = port
            }

            registrationListener = object : NsdManager.RegistrationListener {

                override fun onServiceRegistered(info: NsdServiceInfo) {
                    registeredServiceName = info.serviceName
                    sendToFlutter("onRegistered", mapOf(
                        "serviceName" to info.serviceName
                    ))
                }

                override fun onRegistrationFailed(info: NsdServiceInfo, errorCode: Int) {
                    sendToFlutter("onRegistrationFailed", mapOf(
                        "errorCode" to errorCode
                    ))
                }

                override fun onServiceUnregistered(info: NsdServiceInfo) {
                    registeredServiceName = null
                    sendToFlutter("onUnregistered", emptyMap())
                }

                override fun onUnregistrationFailed(info: NsdServiceInfo, errorCode: Int) {
                    sendToFlutter("onUnregistrationFailed", mapOf(
                        "errorCode" to errorCode
                    ))
                }
            }

            nsdManager.registerService(
                serviceInfo,
                NsdManager.PROTOCOL_DNS_SD,
                registrationListener
            )
        }
    }

    // -------------------------
    // Discovery
    // -------------------------

    private fun startDiscovery(serviceType: String) {
        mainHandler.post {

            acquireMulticastLock()

            discoveryListener = object : NsdManager.DiscoveryListener {

                override fun onDiscoveryStarted(type: String) {
                    sendToFlutter("onDiscoveryStarted", mapOf("serviceType" to type))
                }

                override fun onStartDiscoveryFailed(type: String, errorCode: Int) {
                    sendToFlutter("onDiscoveryStartFailed", mapOf("errorCode" to errorCode))
                }

                override fun onStopDiscoveryFailed(type: String, errorCode: Int) {
                    sendToFlutter("onDiscoveryStopFailed", mapOf("errorCode" to errorCode))
                }

                override fun onDiscoveryStopped(type: String) {
                    sendToFlutter("onDiscoveryStopped", mapOf("serviceType" to type))
                }

                override fun onServiceFound(info: NsdServiceInfo) {

                    if (info.serviceName.equals(registeredServiceName, true)) return

                    nsdManager.resolveService(
                        info,
                        object : NsdManager.ResolveListener {

                            override fun onResolveFailed(service: NsdServiceInfo, errorCode: Int) {
                                sendToFlutter("onResolveFailed", mapOf(
                                    "serviceName" to service.serviceName,
                                    "errorCode" to errorCode
                                ))
                            }

                            override fun onServiceResolved(resolved: NsdServiceInfo) {

                                val address =
                                    resolved.host?.hostAddress ?: return
                                val port = resolved.port
                                val name = resolved.serviceName

                                resolvedServices[name] =
                                    ServiceInfo(name, address, port)

                                sendToFlutter("onServiceDiscovered", mapOf(
                                    "serviceName" to name,
                                    "address" to address,
                                    "port" to port
                                ))
                            }
                        }
                    )
                }

                override fun onServiceLost(info: NsdServiceInfo) {
                    resolvedServices.remove(info.serviceName)
                    sendToFlutter("onServiceLost", mapOf(
                        "serviceName" to info.serviceName
                    ))
                }
            }

            nsdManager.discoverServices(
                serviceType,
                NsdManager.PROTOCOL_DNS_SD,
                discoveryListener
            )
        }
    }

    // -------------------------
    // Stop
    // -------------------------

    private fun stopMdns() {
        mainHandler.post {
            try {
                registrationListener?.let {
                    nsdManager.unregisterService(it)
                }

                discoveryListener?.let {
                    nsdManager.stopServiceDiscovery(it)
                }

                registrationListener = null
                discoveryListener = null
                resolvedServices.clear()
                releaseMulticastLock()

            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    // -------------------------
    // Multicast
    // -------------------------

    private fun acquireMulticastLock() {
        if (multicastLock == null) {
            multicastLock = wifiManager.createMulticastLock("oreon_mdns").apply {
                setReferenceCounted(false)
                acquire()
            }
        }
    }

    private fun releaseMulticastLock() {
        multicastLock?.release()
        multicastLock = null
    }

    // -------------------------
    // Flutter communication
    // -------------------------

    private fun sendToFlutter(method: String, args: Map<String, Any?>) {
        mainHandler.post {
            try {
                methodChannel?.invokeMethod(method, args)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
