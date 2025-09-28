package com.example.drlogger

import com.example.drlogger.audio.AudioRecorderPlugin
import com.example.drlogger.db.LocalDbPlugin
import com.example.drlogger.transcription.TranscriptionPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private lateinit var transcriptionPlugin: TranscriptionPlugin

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        transcriptionPlugin = TranscriptionPlugin(flutterEngine.dartExecutor.binaryMessenger)
        AudioRecorderPlugin(this, flutterEngine.dartExecutor.binaryMessenger, transcriptionPlugin)
        LocalDbPlugin(this, flutterEngine.dartExecutor.binaryMessenger)
    }
}
