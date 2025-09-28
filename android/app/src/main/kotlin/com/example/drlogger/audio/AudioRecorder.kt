package com.example.drlogger.audio

import android.Manifest
import android.content.Context
import android.media.*
import androidx.annotation.RequiresPermission
import java.io.File
import java.io.FileOutputStream
import java.util.*
import kotlin.concurrent.thread
import kotlin.math.abs

class AudioRecorder(
    private val context: Context,
    private val sessionId: String,
    private val chunkSizeMs: Int,
    private val sendEvent: (Map<String, Any>, ByteArray?) -> Unit
) {
    private var audioRecord: AudioRecord? = null
    private var isRecording = false
    private var isPaused = false
    private var chunkCounter = 0
    private var startTime = 0L

    @RequiresPermission(Manifest.permission.RECORD_AUDIO)
    fun start() {
        val sampleRate = 16000
        val minBuffer = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            minBuffer
        )

        audioRecord?.startRecording()
        isRecording = true
        startTime = System.currentTimeMillis()

        thread {
            val bytesPerMs = (sampleRate * 2) / 1000 // 16-bit PCM = 2 bytes/sample
            val buffer = ByteArray(bytesPerMs * chunkSizeMs)

            while (isRecording) {
                if (!isPaused) {
                    val read = audioRecord?.read(buffer, 0, buffer.size) ?: 0
                    if (read > 0) {
                        val chunkData = buffer.copyOf(read)

                        // Save chunk to file
                        val file = File(context.cacheDir, "${UUID.randomUUID()}.pcm")
                        FileOutputStream(file).use { it.write(chunkData) }

                        val amplitude = calculateAmplitude(chunkData)
                        val timestampMs = (System.currentTimeMillis() - startTime).toInt()

                        val event = mapOf(
                            "type" to "chunk",
                            "sessionId" to sessionId,
                            "audioId" to UUID.randomUUID().toString(),
                            "chunkNumber" to chunkCounter++,
                            "filePath" to file.absolutePath,
                            "timestampMs" to timestampMs,
                            "amplitude" to amplitude,
                            "lastChunk" to false
                        )
                        sendEvent(event, chunkData)
                    }
                } else {
                    Thread.sleep(50)
                }
            }
        }
    }

    fun pause() {
        isPaused = true
    }

    fun resume() {
        isPaused = false
    }

    fun stop() {
        isRecording = false
        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null

        // send final chunk marker
        val event = mapOf(
            "type" to "chunk",
            "sessionId" to sessionId,
            "audioId" to UUID.randomUUID().toString(),
            "chunkNumber" to chunkCounter,
            "filePath" to "",
            "timestampMs" to (System.currentTimeMillis() - startTime).toInt(),
            "amplitude" to 0.0,
            "lastChunk" to true
        )
        sendEvent(event, null) // <-- pass null for chunkData for final chunk
    }

    private fun calculateAmplitude(buffer: ByteArray): Double {
        var maxAmp = 0
        var i = 0
        while (i < buffer.size - 1) {
            val value = (buffer[i].toInt() and 0xff) or (buffer[i + 1].toInt() shl 8)
            maxAmp = maxOf(maxAmp, abs(value))
            i += 2
        }
        return maxAmp.toDouble() / Short.MAX_VALUE
    }

    fun getCurrentChunkCounter(): Int = chunkCounter
}
