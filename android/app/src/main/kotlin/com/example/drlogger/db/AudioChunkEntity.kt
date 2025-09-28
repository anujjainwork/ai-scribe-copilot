package com.example.drlogger.db

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "audio_chunks")
data class AudioChunkEntity(
    @PrimaryKey val audioId: String,
    val sessionId: String,
    val chunkNumber: Int,
    val filePath: String,
    val durationMs: Int,
    val status: String,
    val createdAt: Long,
    val gcsPath: String?,
    val publicUrl: String?
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "audioId" to audioId,
        "sessionId" to sessionId,
        "chunkNumber" to chunkNumber,
        "filePath" to filePath,
        "durationMs" to durationMs,
        "status" to status,
        "createdAt" to createdAt,
        "gcsPath" to gcsPath,
        "publicUrl" to publicUrl
    )

    companion object {
        fun fromMap(map: Map<String, Any?>): AudioChunkEntity {
            return AudioChunkEntity(
                audioId = map["audioId"] as String,
                sessionId = map["sessionId"] as String,
                chunkNumber = (map["chunkNumber"] as Number).toInt(),
                filePath = map["filePath"] as String,
                durationMs = (map["durationMs"] as Number).toInt(),
                status = map["status"] as String,
                createdAt = (map["createdAt"] as Number).toLong(),
                gcsPath = map["gcsPath"] as? String,
                publicUrl = map["publicUrl"] as? String
            )
        }
    }
}