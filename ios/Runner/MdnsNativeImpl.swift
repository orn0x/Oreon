// MdnsNativeImpl.swift
//
// iOS native implementation using Bonjour (NSNetService/NSNetServiceBrowser)
// Handles service advertisement and discovery via mDNS
//
// Location: ios/Runner/MdnsNativeImpl.swift

import Foundation

/**
 * iOS mDNS implementation using Bonjour
 *
 * Responsibilities:
 * - Service advertisement via NSNetService
 * - Service discovery via NSNetServiceBrowser
 * - Callback routing to Flutter via MethodChannel
 */
class MdnsNativeImpl: NSObject {
    
    static let channelName = "com.oreon.polygone_app/mdns"
    static let serviceType = "_oreonchat._tcp"
    static let serviceDomain = "local."
    
    private var methodChannel: FlutterMethodChannel?
    private var netService: NetServiceWrapper?
    private var netServiceBrowser: NetServiceBrowserWrapper?
    private var discoveredServices: [String: ServiceInfo] = [:]
    
    struct ServiceInfo {
        let name: String
        let address: String
        let port: Int
    }
    
    /**
     * Initializes the mDNS implementation with Flutter method channel
     */
    func setupChannel(controller: FlutterViewController) {
        methodChannel = FlutterMethodChannel(
            name: Self.channelName,
            binaryMessenger: controller.binaryMessenger
        )
        
        methodChannel?.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "mdns.advertise":
                if let args = call.arguments as? [String: Any],
                   let serviceName = args["serviceName"] as? String,
                   let port = args["port"] as? Int {
                    self?.startAdvertisement(serviceName: serviceName, port: port)
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Missing required arguments", details: nil))
                }
                
            case "mdns.discover":
                self?.startDiscovery()
                result(nil)
                
            case "mdns.stop":
                self?.stopMdns()
                result(nil)
                
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    /**
     * Starts service advertisement
     *
     * Creates NSNetService and publishes it for discovery by other devices
     */
    private func startAdvertisement(serviceName: String, port: Int) {
        netService = NetServiceWrapper(
            name: serviceName,
            type: Self.serviceType,
            domain: Self.serviceDomain,
            port: Int32(port),
            methodChannel: methodChannel
        )
        netService?.publish()
    }
    
    /**
     * Starts service discovery
     *
     * Creates NSNetServiceBrowser and searches for services of the specified type
     */
    private func startDiscovery() {
        netServiceBrowser = NetServiceBrowserWrapper(
            serviceType: Self.serviceType,
            domain: Self.serviceDomain,
            methodChannel: methodChannel,
            onServiceDiscovered: { [weak self] serviceName, address, port in
                self?.discoveredServices[serviceName] = ServiceInfo(
                    name: serviceName,
                    address: address,
                    port: port
                )
            },
            onServiceLost: { [weak self] serviceName in
                self?.discoveredServices.removeValue(forKey: serviceName)
            }
        )
        netServiceBrowser?.browse()
    }
    
    /**
     * Stops all mDNS operations
     */
    private func stopMdns() {
        netService?.stop()
        netService = nil
        
        netServiceBrowser?.stop()
        netServiceBrowser = nil
        
        discoveredServices.removeAll()
    }
}

/**
 * Wrapper for NSNetService to handle service advertisement
 */
class NetServiceWrapper: NSObject, NetServiceDelegate {
    
    private let netService: NetService
    private let methodChannel: FlutterMethodChannel?
    
    init(name: String, type: String, domain: String, port: Int32, methodChannel: FlutterMethodChannel?) {
        self.netService = NetService(domain: domain, type: type, name: name, port: port)
        self.methodChannel = methodChannel
        super.init()
        self.netService.delegate = self
    }
    
    func publish() {
        netService.publish(options: .listenForConnections)
    }
    
    func stop() {
        netService.stop()
    }
    
    // MARK: - NetServiceDelegate
    
    func netServiceDidPublish(_ sender: NetService) {
        methodChannel?.invokeMethod("onRegistered", arguments: [
            "serviceName": sender.name
        ])
    }
    
    func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        if let errorCode = errorDict[NetService.errorCode]?.intValue {
            methodChannel?.invokeMethod("onRegistrationFailed", arguments: [
                "errorCode": errorCode
            ])
        }
    }
    
    func netServiceDidStop(_ sender: NetService) {
        methodChannel?.invokeMethod("onUnregistered", arguments: [:])
    }
}

/**
 * Wrapper for NSNetServiceBrowser to handle service discovery
 */
class NetServiceBrowserWrapper: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
    
    private let browser: NetServiceBrowser
    private let serviceType: String
    private let domain: String
    private let methodChannel: FlutterMethodChannel?
    private let onServiceDiscovered: (String, String, Int) -> Void
    private let onServiceLost: (String) -> Void
    private var resolvedServices: [String: Net ServiceInfo] = [:]
    
    struct NetServiceInfo {
        let service: NetService
        let name: String
    }
    
    init(serviceType: String,
         domain: String,
         methodChannel: FlutterMethodChannel?,
         onServiceDiscovered: @escaping (String, String, Int) -> Void,
         onServiceLost: @escaping (String) -> Void) {
        
        self.browser = NetServiceBrowser()
        self.serviceType = serviceType
        self.domain = domain
        self.methodChannel = methodChannel
        self.onServiceDiscovered = onServiceDiscovered
        self.onServiceLost = onServiceLost
        
        super.init()
        self.browser.delegate = self
    }
    
    func browse() {
        browser.searchForServices(ofType: serviceType, inDomain: domain)
    }
    
    func stop() {
        browser.stop()
        resolvedServices.removeAll()
    }
    
    // MARK: - NetServiceBrowserDelegate
    
    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        // Discovery started
    }
    
    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        // Discovery stopped
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser,
                         didFindDomain domainString: String,
                         moreComing: Bool) {
        // Domain found (not used for our simple use case)
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser,
                         didFind netService: NetService,
                         moreComing: Bool) {
        // Service found - resolve it to get address and port
        let serviceName = netService.name
        
        // Skip duplicate resolution attempts
        if resolvedServices[serviceName] != nil {
            return
        }
        
        // Create resolver wrapper
        let resolver = netService
        resolver.delegate = self
        resolver.resolve(withTimeout: 5.0)
        
        // Track this service
        resolvedServices[serviceName] = NetServiceInfo(service: resolver, name: serviceName)
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser,
                         didRemove netService: NetService,
                         moreComing: Bool) {
        let serviceName = netService.name
        resolvedServices.removeValue(forKey: serviceName)
        
        methodChannel?.invokeMethod("onServiceLost", arguments: [
            "serviceName": serviceName
        ])
        
        onServiceLost(serviceName)
    }
    
    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser,
                                       error errorDict: [String: NSNumber]) {
        if let errorCode = errorDict[NetService.errorCode]?.intValue {
            methodChannel?.invokeMethod("onDiscoveryStopFailed", arguments: [
                "errorCode": errorCode
            ])
        }
    }
    
    // MARK: - NetServiceDelegate (for resolution)
    
    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let addresses = sender.addresses else { return }
        
        // Extract IPv4 address from addresses
        var ipAddress: String?
        for address in addresses {
            ipAddress = addressToString(address)
            if ipAddress != nil && !ipAddress!.contains(":") {
                // Prefer IPv4
                break
            }
        }
        
        guard let address = ipAddress else { return }
        
        let serviceName = sender.name
        let port = sender.port
        
        methodChannel?.invokeMethod("onServiceDiscovered", arguments: [
            "serviceName": serviceName,
            "address": address,
            "port": port
        ])
        
        onServiceDiscovered(serviceName, address, Int(port))
    }
    
    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        if let errorCode = errorDict[NetService.errorCode]?.intValue {
            methodChannel?.invokeMethod("onResolveFailed", arguments: [
                "serviceName": sender.name,
                "errorCode": errorCode
            ])
        }
    }
    
    /**
     * Converts NSData address to string representation
     */
    private func addressToString(_ address: Data) -> String? {
        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        
        guard address.withUnsafeBytes({ bytes -> Int32 in
            getnameinfo(
                bytes.baseAddress?.assumingMemoryBound(to: sockaddr.self),
                socklen_t(address.count),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )
        }) == 0 else {
            return nil
        }
        
        return String(cString: hostname)
    }
}

/**
 * Integration in GeneratedPluginRegistrant or main.swift:
 *
 * In your GeneratedPluginRegistrant.swift or main view controller:
 *
 * override func application(
 *     _ application: UIApplication,
 *     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
 * ) -> Bool {
 *     if let controller = window?.rootViewController as? FlutterViewController {
 *         let mdnsImpl = MdnsNativeImpl()
 *         mdnsImpl.setupChannel(controller: controller)
 *     }
 *     return true
 * }
 *
 * Required Info.plist entries:
 * - NSBonjourServices: [_oreonchat._tcp, _oreonchat._udp]
 * - NSLocalNetworkUsageDescription: "Oreon needs access to your local network
 *   to discover and communicate with nearby devices for LAN chat."
 * - NSBonjourUsageDescription: "Oreon uses Bonjour to discover nearby devices."
 *
 * Optional entries:
 * - UIBackgroundModes: [fetch, processing] (for background operation)
 * - NSAllowsLocalNetworking: true (under NSAppTransportSecurity)
 */
