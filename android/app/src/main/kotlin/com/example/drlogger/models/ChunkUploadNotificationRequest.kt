package com.example.drlogger.models

data class ChunkUploadNotificationRequest(
    val sessionId: String,
    val chunkNumber: Int
)