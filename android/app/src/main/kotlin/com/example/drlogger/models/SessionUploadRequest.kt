package com.example.drlogger.models

data class SessionUploadRequest(
    val patientId: String,
    val userId: String,
    val patientName: String,
    val status: String,
    val startTime: String,
    val templateId: String
)