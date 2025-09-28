package com.example.drlogger.models

data class PresignedUrlResponse(
    val url: String,
    val gcsPath: String?,
    val publicUrl: String?
)