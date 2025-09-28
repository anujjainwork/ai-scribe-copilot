package com.example.drlogger.audio

import android.Manifest
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager
import androidx.annotation.RequiresApi
import androidx.annotation.RequiresPermission
import com.example.drlogger.db.AppDatabase
import com.example.drlogger.db.AudioChunkEntity
import com.example.drlogger.db.SessionEntity
import com.example.drlogger.models.SessionUploadRequest
import com.example.drlogger.repository.ApiRepository
import com.example.drlogger.transcription.TranscriptionPlugin
import com.example.drlogger.upload.UploadForegroundService
import com.example.drlogger.upload.UploadManager
import io.flutter.plugin.common.*
import kotlinx.coroutines.*
import org.json.JSONObject
import org.vosk.Model
import org.vosk.Recognizer
import java.io.File

class AudioRecorderPlugin(
    private val context: Context,
    messenger: BinaryMessenger,
    private val transcriptionPlugin: TranscriptionPlugin
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val methodChannel = MethodChannel(messenger, "drlogger/recorder")
    private val eventChannel = EventChannel(messenger, "drlogger/recorder_events")
    private var eventSink: EventChannel.EventSink? = null
    private var recorder: AudioRecorder? = null

    private var voskModel: Model? = null
    private var voskRecognizer: Recognizer? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private var audioManager: AudioManager? = null
    private var audioFocusChangeListener: AudioManager.OnAudioFocusChangeListener? = null

    private var telephonyManager: TelephonyManager? = null
    private var telephonyCallback: TelephonyCallback? = null

    private var activeSessionId: String? = null

    private val repo = ApiRepository()
    private val ioScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    // ------------------------------------------
    // Call State Handling (Phone Calls)
    // ------------------------------------------
    @RequiresApi(Build.VERSION_CODES.S)
    private fun registerCallStateCallback() {
        telephonyManager = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        telephonyCallback = object : TelephonyCallback(), TelephonyCallback.CallStateListener {
            override fun onCallStateChanged(state: Int) {
                when (state) {
                    TelephonyManager.CALL_STATE_RINGING,
                    TelephonyManager.CALL_STATE_OFFHOOK -> {
                        Log.d("Recorder", "Phone call detected, pausing recorder")
                        recorder?.pause()
                        activeSessionId?.let { sendStatus(it, "paused_by_call") }
                    }
                    TelephonyManager.CALL_STATE_IDLE -> {
                        Log.d("Recorder", "Call ended, resuming recorder")
                        recorder?.resume()
                        activeSessionId?.let { sendStatus(it, "resumed_after_call") }
                    }
                }
            }
        }
        telephonyManager?.registerTelephonyCallback(context.mainExecutor, telephonyCallback as TelephonyCallback)
    }

    @RequiresApi(Build.VERSION_CODES.S)
    private fun unregisterCallStateCallback() {
        telephonyCallback?.let { telephonyManager?.unregisterTelephonyCallback(it) }
        telephonyCallback = null
    }

    // ------------------------------------------
    // Audio Focus Handling (Alarms, Media, etc.)
    // ------------------------------------------
    private fun setupAudioFocus(sessionId: String) {
        audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audioFocusChangeListener = AudioManager.OnAudioFocusChangeListener { focusChange ->
            when (focusChange) {
                AudioManager.AUDIOFOCUS_LOSS,
                AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                    Log.d("Recorder", "Audio focus lost, pausing")
                    recorder?.pause()
                    sendStatus(sessionId, "paused_by_focus")
                }
                AudioManager.AUDIOFOCUS_GAIN -> {
                    Log.d("Recorder", "Audio focus gained, resuming")
                    recorder?.resume()
                    sendStatus(sessionId, "resumed_after_focus")
                }
            }
        }
        audioManager?.requestAudioFocus(
            audioFocusChangeListener,
            AudioManager.STREAM_MUSIC,
            AudioManager.AUDIOFOCUS_GAIN
        )
    }

    private fun abandonAudioFocus() {
        audioFocusChangeListener?.let { audioManager?.abandonAudioFocus(it) }
    }

    // ------------------------------------------
    // MethodChannel handling
    // ------------------------------------------
    @RequiresApi(Build.VERSION_CODES.O)
    @RequiresPermission(Manifest.permission.RECORD_AUDIO)
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startRecording" -> startRecording(call, result)
            "pauseRecording" -> {
                val sessionId = call.argument<String>("session_id")!!
                recorder?.pause()
                sendStatus(sessionId, "paused")
                result.success(null)
            }
            "resumeRecording" -> {
                val sessionId = call.argument<String>("session_id")!!
                recorder?.resume()
                sendStatus(sessionId, "resumed")
                result.success(null)
            }
            "stopRecording" -> stopRecording(call, result)
            else -> result.notImplemented()
        }
    }

    // ------------------------------------------
    // Start / Stop recording
    // ------------------------------------------
    @RequiresApi(Build.VERSION_CODES.O)
    @RequiresPermission(Manifest.permission.RECORD_AUDIO)
    private fun startRecording(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as Map<*, *>
        val sessionId = args["sessionId"] as String
        val chunkSizeMs = args["chunkSizeMs"] as Int
        val patientId = args["patientId"] as? String
        val serverSessionId = args["serverSessionId"] as? String

        activeSessionId = sessionId
        setupAudioFocus(sessionId)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) registerCallStateCallback()

        // Init Vosk in background
        ioScope.launch {
            try {
                val modelDir = File(context.filesDir, "vosk-model")
                if (!modelDir.exists() || modelDir.listFiles()?.isEmpty() != false) {
                    copyAssetModel(context, "vosk-model", modelDir)
                }

                if (modelDir.listFiles().isNullOrEmpty()) throw RuntimeException("Vosk model folder empty!")

                voskModel = Model(modelDir.absolutePath)
                voskRecognizer = Recognizer(voskModel, 16000.0f)
                Log.d("Vosk", "Recognizer initialized")

                mainHandler.post { startAudioRecorder(sessionId, chunkSizeMs) }
            } catch (e: Exception) {
                Log.e("Vosk", "Failed to initialize recognizer", e)
                sendStatus(sessionId, "error", e.message)
            }
        }

        insertSessionToDb(sessionId, serverSessionId, patientId)

        // Upload session metadata to server
        ioScope.launch {
            try {
                val response = repo.uploadSession(
                    SessionUploadRequest(
                        patientId = patientId ?: "unknown",
                        userId = "unknown",
                        patientName = "unknown",
                        status = "recording",
                        startTime = System.currentTimeMillis().toString(),
                        templateId = "new_patient_visit"
                    )
                )
                Log.d("SessionUpload", "Success: ${response.success} | ${response.message}")
            } catch (e: Exception) {
                Log.e("SessionUpload", "Error uploading session", e)
            }
        }

        sendStatus(sessionId, "started")
        result.success(null)
    }

    @RequiresApi(Build.VERSION_CODES.O)
    @RequiresPermission(Manifest.permission.RECORD_AUDIO)
    private fun stopRecording(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as Map<*, *>
        val sessionId = args["sessionId"] as String

        recorder?.stop()
        stopVosk()
        abandonAudioFocus()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) unregisterCallStateCallback()

        sendStatus(sessionId, "stopped")
        endSessionInDb(sessionId)
        recorder = null
        activeSessionId = null
        result.success(null)
    }

    // ------------------------------------------
    // EventChannel
    // ------------------------------------------
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { eventSink = events }
    override fun onCancel(arguments: Any?) { eventSink = null }
    private fun sendStatus(sessionId: String, status: String, errorMessage: String? = null) {
        val map = mapOf(
            "type" to "status",
            "sessionId" to sessionId,
            "status" to status,
            "errorMessage" to errorMessage
        )
        mainHandler.post { eventSink?.success(map) }
    }

    // ------------------------------------------
    // Vosk
    // ------------------------------------------
    private fun stopVosk() {
        voskRecognizer?.close()
        voskRecognizer = null
        voskModel = null
        Log.d("Vosk", "Recognizer stopped")
    }

    private fun copyAssetModel(context: Context, assetFolder: String, targetFolder: File) {
        if (!targetFolder.exists()) targetFolder.mkdirs()
        val assetManager = context.assets
        val files = assetManager.list(assetFolder) ?: return
        for (file in files) {
            val assetPath = "$assetFolder/$file"
            val outFile = File(targetFolder, file)
            if (assetManager.list(assetPath)?.isNotEmpty() == true) {
                copyAssetModel(context, assetPath, outFile)
            } else {
                assetManager.open(assetPath).use { input ->
                    outFile.outputStream().use { output -> input.copyTo(output) }
                }
            }
        }
    }

    // ------------------------------------------
    // AudioChunk / Session DB
    // ------------------------------------------
    @RequiresApi(Build.VERSION_CODES.O)
    private fun insertAudioChunkToDb(
        sessionId: String,
        chunkNumber: Int,
        filePath: String,
        durationMs: Int,
        status: String
    ) {
        val chunk = AudioChunkEntity(
            audioId = "$sessionId-$chunkNumber",
            sessionId = sessionId,
            chunkNumber = chunkNumber,
            filePath = filePath,
            durationMs = durationMs,
            status = status,
            createdAt = System.currentTimeMillis(),
            gcsPath = null,
            publicUrl = null
        )

        ioScope.launch {
            try {
                val db = AppDatabase.getDatabase(context)
                db.audioChunkDao().insert(chunk)
                UploadManager.getInstance(context).enqueueChunk(chunk)

                val svcIntent = Intent(context, UploadForegroundService::class.java)
                try { context.startForegroundService(svcIntent) } catch (e: Exception) { context.startService(svcIntent) }

                Log.d("DB", "Inserted & enqueued chunk ${chunk.audioId}")
            } catch (e: Exception) {
                Log.e("DB", "Error inserting chunk", e)
            }
        }
    }

    private fun insertSessionToDb(sessionId: String, serverSessionId: String?, patientId: String?, status: String = "active") {
        val session = SessionEntity(
            sessionId = sessionId,
            serverSessionId = serverSessionId ?: "",
            patientId = patientId ?: "unknown",
            status = status,
            startTime = System.currentTimeMillis(),
            endTime = null
        )
        ioScope.launch {
            try {
                val db = AppDatabase.getDatabase(context)
                db.sessionDao().insertSession(session)
                Log.d("DB", "Inserted session $sessionId")
            } catch (e: Exception) { Log.e("DB", "Error inserting session", e) }
        }
    }

    private fun endSessionInDb(sessionId: String, status: String = "completed") {
        ioScope.launch {
            try {
                val db = AppDatabase.getDatabase(context)
                db.sessionDao().endSession(sessionId, System.currentTimeMillis(), status)
                Log.d("DB", "Ended session $sessionId")
            } catch (e: Exception) { Log.e("DB", "Error ending session", e) }
        }
    }

    // ------------------------------------------
    // AudioRecorder initialization
    // ------------------------------------------
    @RequiresApi(Build.VERSION_CODES.O)
    @RequiresPermission(Manifest.permission.RECORD_AUDIO)
    private fun startAudioRecorder(sessionId: String, chunkSizeMs: Int) {
        recorder = AudioRecorder(context, sessionId, chunkSizeMs) { event, chunkData ->
            mainHandler.post { eventSink?.success(event) }

            chunkData?.let { data ->
                voskRecognizer?.let { recognizer ->
                    try {
                        val accepted = recognizer.acceptWaveForm(data, data.size)
                        val rawJson = if (accepted) recognizer.result else recognizer.partialResult

                        // Parse JSON
                        val jsonObject = JSONObject(rawJson)
                        val text = if (accepted) {
                            jsonObject.optString("text")
                        } else {
                            jsonObject.optString("partial")
                        }

                        transcriptionPlugin.sendTranscription(
                            sessionId,
                            event["chunkNumber"] as Int,
                            text,
                            accepted
                        )

                        insertAudioChunkToDb(
                            sessionId = sessionId,
                            chunkNumber = event["chunkNumber"] as Int,
                            filePath = event["filePath"] as String,
                            durationMs = (event["durationMs"] as? Int) ?: 0,
                            status = "pending"
                        )

                        Log.d("Vosk", if (accepted) "Final: $text" else "Partial: $text")
                    } catch (e: Exception) {
                        Log.e("Vosk", "Error feeding PCM to recognizer", e)
                    }
                }
            }
        }
        recorder?.start()
    }
}