package com.example.drlogger.models

data class FileIoResponse(
    val success: Boolean,
    val key: String?,
    val link: String?,    // This is the public URL
    val expiry: String?
)
