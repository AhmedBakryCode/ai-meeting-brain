package com.example.meeting_brain

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.meeting_brain/audio_manager"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            
            when (call.method) {
                "setCommunicationMode" -> {
                    try {
                        // Set phone mode to communication (VoIP standard)
                        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
                        
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val playbackAttributes = AudioAttributes.Builder()
                                .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                                .build()
                                
                            val focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                                .setAudioAttributes(playbackAttributes)
                                .setAcceptsDelayedFocusGain(true)
                                .setOnAudioFocusChangeListener { }
                                .build()
                                
                            audioManager.requestAudioFocus(focusRequest)
                        } else {
                            @Suppress("DEPRECATION")
                            audioManager.requestAudioFocus(null, AudioManager.STREAM_VOICE_CALL, AudioManager.AUDIOFOCUS_GAIN)
                        }
                        
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("AUDIO_ERROR", e.message, null)
                    }
                }
                "resetAudioMode" -> {
                    audioManager.mode = AudioManager.MODE_NORMAL
                    @Suppress("DEPRECATION")
                    audioManager.abandonAudioFocus(null)
                    result.success(true)
                }
                "setSpeakerphoneOn" -> {
                    val on = call.argument<Boolean>("on") ?: true
                    audioManager.isSpeakerphoneOn = on
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
