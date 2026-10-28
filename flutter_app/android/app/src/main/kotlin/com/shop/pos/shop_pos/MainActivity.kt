package com.shop.pos.shop_pos

import android.content.res.AssetFileDescriptor
import android.media.AudioAttributes
import android.media.SoundPool
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.shop.pos/native_sound"
    private var soundPool: SoundPool? = null
    private val soundMap = HashMap<String, Int>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        initSoundPool()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "playClick" -> {
                    result.success(playSound("click"))
                }
                "playProductAdd" -> {
                    result.success(playSound("beep"))
                }
                "playDelete" -> {
                    result.success(playSound("delete"))
                }
                "playDot" -> {
                    result.success(playSound("dot"))
                }
                "playSuccess" -> {
                    result.success(playSound("success"))
                }
                "playAppStartup" -> {
                    result.success(playSound("success"))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun initSoundPool() {
        try {
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()

            soundPool = SoundPool.Builder()
                .setMaxStreams(10)
                .setAudioAttributes(audioAttributes)
                .build()

            loadSound("click", "flutter_assets/assets/sounds/click.wav")
            loadSound("beep", "flutter_assets/assets/sounds/beep.wav")
            loadSound("delete", "flutter_assets/assets/sounds/delete.wav")
            loadSound("dot", "flutter_assets/assets/sounds/dot.wav")
            loadSound("success", "flutter_assets/assets/sounds/success.wav")
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun loadSound(key: String, assetPath: String) {
        try {
            val afd: AssetFileDescriptor = assets.openFd(assetPath)
            val soundId = soundPool?.load(afd, 1) ?: 0
            if (soundId != 0) {
                soundMap[key] = soundId
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun playSound(key: String): Boolean {
        val soundId = soundMap[key] ?: return false
        if (soundId == 0) return false
        val volume = when (key) {
            "click" -> 0.40f
            "dot" -> 0.45f
            "beep" -> 0.50f
            "delete" -> 0.55f
            "success" -> 0.60f
            else -> 0.50f
        }
        val streamId = soundPool?.play(soundId, volume, volume, 1, 0, 1.0f) ?: 0
        return streamId != 0
    }

    override fun onDestroy() {
        super.onDestroy()
        soundPool?.release()
        soundPool = null
        soundMap.clear()
    }
}
