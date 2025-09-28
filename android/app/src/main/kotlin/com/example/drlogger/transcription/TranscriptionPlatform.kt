package com.example.drlogger.transcription

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel

class TranscriptionPlugin(
    messenger: BinaryMessenger
) : EventChannel.StreamHandler {

    private val eventChannel = EventChannel(messenger, "drlogger/transcription_events")
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    init {
        eventChannel.setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun sendTranscription(sessionId: String, chunkNumber: Int, text: String, isFinal: Boolean) {
        val map = mapOf(
            "sessionId" to sessionId,
            "chunkNumber" to chunkNumber,
            "partialText" to text,
            "isFinal" to isFinal
        )
        mainHandler.post {
            eventSink?.success(map)
        }
    }
}