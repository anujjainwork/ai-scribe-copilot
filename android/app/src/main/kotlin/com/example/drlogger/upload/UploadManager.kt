package com.example.drlogger.upload

import android.annotation.SuppressLint
import android.content.Context
import android.util.Log
import com.example.drlogger.db.AppDatabase
import com.example.drlogger.db.AudioChunkEntity
import com.example.drlogger.models.ChunkUploadNotificationRequest
import com.example.drlogger.models.ChunkUploadRequest
import com.example.drlogger.repository.ApiRepository
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlin.math.min
import kotlin.time.Duration
import kotlin.time.Duration.Companion.seconds
import java.io.File

/**
 * UploadManager
 *
 * - Singleton.
 * - Enqueue chunk objects for upload.
 * - Ensures per-session ordering via a Mutex per sessionId.
 * - Retries with backoff and marks DB status accordingly.
 * - Exposes resumePendingUploads() to recover on service start.
 *
 * Assumptions:
 * - AppDatabase.audioChunkDao() has methods:
 *   - suspend fun updateStatus(audioId: String, status: String)
 *   - suspend fun getPendingOrRetrying(): List<AudioChunkEntity>
 *
 * - ApiRepository implements:
 *   - suspend fun getPresignedUrl(request: ChunkUploadRequest): PresignedUrlResponse
 *   - suspend fun uploadChunkToUrl(url: String, fileBytes: ByteArray)
 *   - suspend fun notifyChunkUploaded(request: ChunkUploadNotificationRequest)
 */
class UploadManager private constructor(private val context: Context) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val repo = ApiRepository()

    // Map of sessionId -> Mutex to ensure ordered uploads per session
    private val sessionLocks = mutableMapOf<String, Mutex>()

    companion object {
        @SuppressLint("StaticFieldLeak")
        @Volatile
        private var INSTANCE: UploadManager? = null

        fun getInstance(context: Context): UploadManager {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: UploadManager(context.applicationContext).also { INSTANCE = it }
            }
        }
    }

    /**
     * Enqueue single chunk for upload.
     * This will run in background; for ordering we use a per-session mutex.
     */
    fun enqueueChunk(chunk: AudioChunkEntity) {
        scope.launch {
            val lock = sessionLocks.getOrPut(chunk.sessionId) { Mutex() }
            lock.withLock {
                uploadWithRetry(chunk)
            }
        }
    }

    /**
     * Try to upload chunk with retries and exponential-ish backoff.
     * Updates DB status on each attempt/result.
     */
    private suspend fun uploadWithRetry(chunk: AudioChunkEntity) {
        val db = AppDatabase.getDatabase(context)
        val maxAttempts = 5
        var attempt = 0
        var backoff: Duration = 2.seconds

        while (attempt < maxAttempts) {
            attempt++
            try {
                // Check file exists
                val file = File(chunk.filePath)
                if (!file.exists()) {
                    db.audioChunkDao().updateStatus(chunk.audioId, "missing")
                    Log.e("UploadManager", "File missing for ${chunk.audioId}")
                    return
                }

                // Get presigned URL (server returns field `url`)
                val presigned = repo.getPresignedUrl(
                    ChunkUploadRequest(
                        sessionId = chunk.sessionId,
                        chunkNumber = chunk.chunkNumber,
                        mimeType = "audio/wav"
                    )
                )
                val presignedUrl = presigned.url
                if (presignedUrl.isNullOrEmpty()) {
                    throw IllegalStateException("No presigned url for ${chunk.audioId}")
                }

                // Read bytes and upload
                val bytes = file.readBytes()
                repo.uploadChunkToUrl(presignedUrl, bytes) // suspend

                // Notify backend
                repo.notifyChunkUploaded(
                    ChunkUploadNotificationRequest(
                        sessionId = chunk.sessionId,
                        chunkNumber = chunk.chunkNumber
                    )
                )

                // Success -> update DB
                db.audioChunkDao().updateStatus(chunk.audioId, "uploaded")
                Log.d("UploadManager", "Uploaded ${chunk.audioId} successfully")
                return // done
            } catch (e: Exception) {
                Log.e("UploadManager", "Attempt $attempt failed for ${chunk.audioId}", e)
                db.audioChunkDao().updateStatus(chunk.audioId, "retrying:$attempt")

                if (attempt >= maxAttempts) {
                    db.audioChunkDao().updateStatus(chunk.audioId, "failed")
                    Log.e("UploadManager", "Max attempts reached for ${chunk.audioId}, marked failed")
                    // Optionally schedule a WorkManager retry here (hook point)
                    return
                } else {
                    // Backoff with tiny jitter
                    val jitter = (0..500).random()
                    delay(backoff.inWholeMilliseconds + jitter)
                    backoff = (backoff * 2).coerceAtMost(30.seconds)
                }
            }
        }
    }

    /**
     * Called on service start or app startup to resume any pending chunks
     * (pending, retrying, or failed depending on your policy).
     */
    fun resumePendingUploads() {
        scope.launch {
            try {
                val db = AppDatabase.getDatabase(context)
                val pending = db.audioChunkDao().getPendingOrRetrying()
                // sort by session then chunkNumber (so ordering is preserved)
                val sorted = pending.sortedWith(compareBy({ it.sessionId }, { it.chunkNumber }))
                sorted.forEach { enqueueChunk(it) }
            } catch (e: Exception) {
                Log.e("UploadManager", "Error resuming pending uploads", e)
            }
        }
    }
}