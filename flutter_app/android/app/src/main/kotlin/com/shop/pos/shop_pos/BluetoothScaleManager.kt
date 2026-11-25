package com.shop.pos.shop_pos

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.UUID
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong

/**
 * Rock-solid Bluetooth Classic SPP manager for retail weighing scales.
 *
 * Fixes upstream bluetooth_classic plugin issues:
 * - Connects on a background I/O thread instead of freezing Android UI thread.
 * - Falls back across secure, insecure, and channel-1 RFCOMM sockets for wide scale chip support.
 * - Handles stream EOF (numBytes <= 0) cleanly without NegativeArraySizeException.
 * - Monitors ACTION_ACL_DISCONNECTED and ACTION_STATE_CHANGED for instant drop detection.
 * - Exposes thread-safe isSocketAlive() so Dart watchdog detects half-open/silent links.
 */
class BluetoothScaleManager(
    private val context: Context,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "BluetoothScaleManager"
        private const val METHOD_CHANNEL = "com.shop.pos/bluetooth_scale"
        private const val DATA_CHANNEL = "com.shop.pos/bluetooth_scale_data"
        private const val STATUS_CHANNEL = "com.shop.pos/bluetooth_scale_status"
        private const val DEFAULT_SPP_UUID = "00001101-0000-1000-8000-00805F9B34FB"

        const val STATUS_DISCONNECTED = 0
        const val STATUS_CONNECTING = 1
        const val STATUS_CONNECTED = 2
        const val STATUS_ADAPTER_ON = 3
    }

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val dataChannel = EventChannel(messenger, DATA_CHANNEL)
    private val statusChannel = EventChannel(messenger, STATUS_CHANNEL)

    private val mainHandler = Handler(Looper.getMainLooper())
    private val connectExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val writeExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val socketLock = Any()
    private val connectionGeneration = AtomicLong(0)

    private var dataSink: EventChannel.EventSink? = null
    private var statusSink: EventChannel.EventSink? = null

    @Volatile
    private var activeSocket: BluetoothSocket? = null

    @Volatile
    private var readThread: ReadThread? = null

    @Volatile
    private var activeMac: String? = null

    private var receiverRegistered = false
    private var isReleased = false

    private val bluetoothAdapter: BluetoothAdapter?
        get() {
            val manager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            return manager?.adapter
        }

    private val aclReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, intent: Intent?) {
            if (intent == null || isReleased) return
            when (intent.action) {
                BluetoothDevice.ACTION_ACL_DISCONNECTED -> {
                    val device: BluetoothDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                    }
                    val disconnectedMac = device?.address
                    val currentMac = activeMac
                    if (disconnectedMac != null &&
                        currentMac != null &&
                        disconnectedMac.equals(currentMac, ignoreCase = true)
                    ) {
                        Log.w(TAG, "ACL link disconnected for scale $disconnectedMac")
                        connectionGeneration.incrementAndGet()
                        closeConnectionInternal(emitDisconnected = true)
                    }
                }
                BluetoothAdapter.ACTION_STATE_CHANGED -> {
                    val state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR)
                    if (state == BluetoothAdapter.STATE_OFF || state == BluetoothAdapter.STATE_TURNING_OFF) {
                        Log.w(TAG, "Bluetooth adapter turned off; closing scale socket")
                        connectionGeneration.incrementAndGet()
                        closeConnectionInternal(emitDisconnected = true)
                    } else if (state == BluetoothAdapter.STATE_ON) {
                        Log.i(TAG, "Bluetooth adapter turned back on")
                        publishStatus(STATUS_ADAPTER_ON)
                    }
                }
            }
        }
    }

    init {
        methodChannel.setMethodCallHandler(this)
        dataChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                dataSink = events
            }

            override fun onCancel(arguments: Any?) {
                dataSink = null
            }
        })
        statusChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                statusSink = events
            }

            override fun onCancel(arguments: Any?) {
                statusSink = null
            }
        })
        registerBluetoothReceiver()
    }

    private fun registerBluetoothReceiver() {
        if (receiverRegistered) return
        try {
            val filter = IntentFilter().apply {
                addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED)
                addAction(BluetoothAdapter.ACTION_STATE_CHANGED)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.registerReceiver(aclReceiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                @Suppress("UnspecifiedRegisterReceiverFlag")
                context.registerReceiver(aclReceiver, filter)
            }
            receiverRegistered = true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register BT ACL receiver: ${e.message}")
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "connect" -> {
                val address = call.argument<String>("address")
                val uuidStr = call.argument<String>("serviceUuid") ?: DEFAULT_SPP_UUID
                if (address.isNullOrBlank()) {
                    result.success(false)
                    return
                }
                connectAsync(address.trim(), uuidStr.trim(), result)
            }
            "disconnect" -> {
                connectionGeneration.incrementAndGet()
                closeConnectionInternal(emitDisconnected = true)
                result.success(true)
            }
            "write" -> {
                val msg = call.argument<String>("message") ?: ""
                writeAsync(msg, result)
            }
            "isSocketAlive" -> {
                result.success(isSocketAlive())
            }
            "getBondedDevices" -> {
                result.success(getBondedDevices())
            }
            else -> result.notImplemented()
        }
    }

    private fun hasBluetoothConnectPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.BLUETOOTH_CONNECT
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    @SuppressLint("MissingPermission")
    private fun getBondedDevices(): List<Map<String, String>> {
        val adapter = bluetoothAdapter ?: return emptyList()
        if (!hasBluetoothConnectPermission()) return emptyList()
        return try {
            val bonded = adapter.bondedDevices ?: emptySet()
            bonded.mapNotNull { device ->
                val addr = device.address ?: return@mapNotNull null
                val name = device.name ?: "Bluetooth Device"
                mapOf("name" to name, "address" to addr)
            }
        } catch (e: Exception) {
            Log.w(TAG, "getBondedDevices error: ${e.message}")
            emptyList()
        }
    }

    private fun isSocketAlive(): Boolean {
        val adapter = bluetoothAdapter ?: return false
        if (!adapter.isEnabled) return false
        synchronized(socketLock) {
            val sock = activeSocket ?: return false
            val thread = readThread ?: return false
            return try {
                sock.isConnected && thread.keepReading && thread.isAlive
            } catch (_: Exception) {
                false
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun connectAsync(address: String, uuidStr: String, result: MethodChannel.Result) {
        val replied = AtomicBoolean(false)
        fun replyOnce(ok: Boolean) {
            if (replied.compareAndSet(false, true)) {
                mainHandler.post { result.success(ok) }
            }
        }

        val adapter = bluetoothAdapter
        if (adapter == null || !adapter.isEnabled || !hasBluetoothConnectPermission()) {
            publishStatus(STATUS_DISCONNECTED)
            replyOnce(false)
            return
        }

        val generation = connectionGeneration.incrementAndGet()
        publishStatus(STATUS_CONNECTING)

        connectExecutor.execute {
            if (isReleased || generation != connectionGeneration.get()) {
                replyOnce(false)
                return@execute
            }

            closeConnectionInternal(emitDisconnected = false)

            val uuid = try {
                UUID.fromString(uuidStr)
            } catch (_: Exception) {
                UUID.fromString(DEFAULT_SPP_UUID)
            }

            val remoteDevice = try {
                adapter.getRemoteDevice(address)
            } catch (e: Exception) {
                Log.e(TAG, "Invalid MAC address $address: ${e.message}")
                publishStatus(STATUS_DISCONNECTED)
                replyOnce(false)
                return@execute
            }

            try {
                if (adapter.isDiscovering) {
                    adapter.cancelDiscovery()
                }
            } catch (_: Exception) {}

            val connectedSocket = openRfcommSocketWithFallbacks(remoteDevice, uuid)
            if (connectedSocket == null || isReleased || generation != connectionGeneration.get()) {
                try {
                    connectedSocket?.close()
                } catch (_: Exception) {}
                if (generation == connectionGeneration.get()) {
                    publishStatus(STATUS_DISCONNECTED)
                }
                replyOnce(false)
                return@execute
            }

            synchronized(socketLock) {
                if (isReleased || generation != connectionGeneration.get()) {
                    try {
                        connectedSocket.close()
                    } catch (_: Exception) {}
                    replyOnce(false)
                    return@execute
                }
                activeMac = address
                activeSocket = connectedSocket
                val reader = ReadThread(connectedSocket, generation)
                readThread = reader
                reader.start()
            }

            publishStatus(STATUS_CONNECTED)
            replyOnce(true)
        }
    }

    @SuppressLint("MissingPermission")
    private fun openRfcommSocketWithFallbacks(device: BluetoothDevice, uuid: UUID): BluetoothSocket? {
        // Strategy 1: Standard Secure RFCOMM SPP
        try {
            val secureSocket = device.createRfcommSocketToServiceRecord(uuid)
            secureSocket.connect()
            return secureSocket
        } catch (e: Exception) {
            Log.w(TAG, "Secure RFCOMM connect failed (${e.message}), trying insecure RFCOMM...")
        }

        // Strategy 2: Insecure RFCOMM SPP (required by many HC-05 / Essae / Phoenix scale modules)
        try {
            val insecureSocket = device.createInsecureRfcommSocketToServiceRecord(uuid)
            insecureSocket.connect()
            return insecureSocket
        } catch (e: Exception) {
            Log.w(TAG, "Insecure RFCOMM connect failed (${e.message}), trying channel 1 fallback...")
        }

        // Strategy 3: Direct RFCOMM Channel 1 reflection fallback
        try {
            val method = device.javaClass.getMethod("createRfcommSocket", Int::class.javaPrimitiveType)
            val channelSocket = method.invoke(device, 1) as? BluetoothSocket
            if (channelSocket != null) {
                channelSocket.connect()
                return channelSocket
            }
        } catch (e: Exception) {
            Log.e(TAG, "All RFCOMM connection strategies failed: ${e.message}")
        }

        return null
    }

    private fun writeAsync(message: String, result: MethodChannel.Result) {
        val replied = AtomicBoolean(false)
        fun replyOnce(ok: Boolean) {
            if (replied.compareAndSet(false, true)) {
                mainHandler.post { result.success(ok) }
            }
        }

        if (message.isEmpty()) {
            replyOnce(false)
            return
        }

        val sock = synchronized(socketLock) { activeSocket }
        if (sock == null || !sock.isConnected) {
            replyOnce(false)
            return
        }

        writeExecutor.execute {
            try {
                sock.outputStream.write(message.toByteArray(Charsets.US_ASCII))
                sock.outputStream.flush()
                replyOnce(true)
            } catch (e: IOException) {
                Log.w(TAG, "Write to scale failed: ${e.message}")
                closeConnectionInternal(emitDisconnected = true)
                replyOnce(false)
            } catch (e: Exception) {
                Log.w(TAG, "Unexpected scale write error: ${e.message}")
                replyOnce(false)
            }
        }
    }

    private fun closeConnectionInternal(emitDisconnected: Boolean) {
        var didCloseAnything = false
        synchronized(socketLock) {
            val thread = readThread
            val sock = activeSocket
            if (thread != null) {
                thread.keepReading = false
                try {
                    thread.interrupt()
                } catch (_: Exception) {}
                readThread = null
                didCloseAnything = true
            }
            if (sock != null) {
                try {
                    sock.close()
                } catch (_: Exception) {}
                activeSocket = null
                didCloseAnything = true
            }
            activeMac = null
        }
        if (emitDisconnected && didCloseAnything) {
            publishStatus(STATUS_DISCONNECTED)
        }
    }

    private inner class ReadThread(
        private val socket: BluetoothSocket,
        private val generation: Long
    ) : Thread("ScaleReadThread-$generation") {

        @Volatile
        var keepReading = true

        override fun run() {
            val inputStream = try {
                socket.inputStream
            } catch (e: IOException) {
                Log.e(TAG, "Unable to open scale inputStream: ${e.message}")
                finishThread()
                return
            }

            val buffer = ByteArray(1024)
            while (keepReading && !isInterrupted) {
                try {
                    val numBytes = inputStream.read(buffer)
                    if (numBytes < 0) {
                        // Stream EOF cleanly signals remote scale disconnect/sleep
                        Log.w(TAG, "Scale inputStream reached EOF (-1)")
                        break
                    }
                    if (numBytes > 0) {
                        val payload = buffer.copyOf(numBytes)
                        mainHandler.post {
                            if (!isReleased) {
                                dataSink?.success(payload)
                            }
                        }
                    }
                } catch (e: IOException) {
                    if (keepReading) {
                        Log.w(TAG, "Scale inputStream disconnected: ${e.message}")
                    }
                    break
                } catch (e: Exception) {
                    if (keepReading) {
                        Log.e(TAG, "Unexpected scale read error: ${e.message}")
                    }
                    break
                }
            }

            finishThread()
        }

        private fun finishThread() {
            keepReading = false
            var shouldEmitDisconnected = false
            synchronized(socketLock) {
                if (readThread === this && generation == connectionGeneration.get()) {
                    readThread = null
                    try {
                        socket.close()
                    } catch (_: Exception) {}
                    activeSocket = null
                    activeMac = null
                    shouldEmitDisconnected = true
                }
            }
            if (shouldEmitDisconnected) {
                publishStatus(STATUS_DISCONNECTED)
            }
        }
    }

    private fun publishStatus(status: Int) {
        if (isReleased) return
        mainHandler.post {
            if (!isReleased) {
                statusSink?.success(status)
            }
        }
    }

    fun release() {
        isReleased = true
        connectionGeneration.incrementAndGet()
        closeConnectionInternal(emitDisconnected = false)
        if (receiverRegistered) {
            try {
                context.unregisterReceiver(aclReceiver)
            } catch (_: Exception) {}
            receiverRegistered = false
        }
        try {
            connectExecutor.shutdownNow()
            writeExecutor.shutdownNow()
        } catch (_: Exception) {}
        methodChannel.setMethodCallHandler(null)
    }
}
