package com.example.drlogger.models

data class ChunkUploadRequest(
    val sessionId: String,
    val chunkNumber: Int,
    val mimeType: String
)
