package com.example.drlogger.repository

import com.example.drlogger.models.*
import com.example.drlogger.network.ApiClient
import com.example.drlogger.network.ApiService
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.toRequestBody

class ApiRepository {
    private val apiService = ApiClient.retrofit.create(ApiService::class.java)

    suspend fun pingServer() = apiService.pingServer()
    suspend fun uploadSession(request: SessionUploadRequest) = apiService.uploadSession(request)

    suspend fun getPresignedUrl(request: ChunkUploadRequest) =
        apiService.getPresignedUrl(request)

    suspend fun uploadChunkToUrl(url: String, fileBytes: ByteArray) =
        apiService.uploadChunkToUrl(url, fileBytes)

    suspend fun notifyChunkUploaded(request: ChunkUploadNotificationRequest) =
        apiService.notifyChunkUploaded(request)

    suspend fun uploadFile(fileBytes: ByteArray, fileName: String = "chunk.wav"): FileIoResponse? {
        val requestFile = fileBytes.toRequestBody("audio/wav".toMediaTypeOrNull())
        val body = MultipartBody.Part.createFormData("file", fileName, requestFile)

        val response = apiService.uploadFile(body)
        if (response.isSuccessful) {
            return response.body()
        } else {
            // You can log response.errorBody() if needed
            return null
        }
    }

}