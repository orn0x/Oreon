package com.example.polygone_app

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    companion object {
        var flutterEngineRef: FlutterEngine? = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Store reference for mDNS callbacks
        flutterEngineRef = flutterEngine
        
        // Initialize mDNS implementation
        val mdnsImpl = MdnsNativeImpl(this, flutterEngine)
        mdnsImpl.setupChannel()
    }
}