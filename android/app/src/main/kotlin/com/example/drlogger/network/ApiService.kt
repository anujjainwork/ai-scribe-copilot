package com.example.drlogger.network

import com.example.drlogger.models.*
import okhttp3.MultipartBody
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.Multipart
import retrofit2.http.POST
import retrofit2.http.PUT
import retrofit2.http.Part
import retrofit2.http.Query
import retrofit2.http.Url
import retrofit2.Response


interface ApiService {

    @GET("ping")
    suspend fun pingServer(): String

    @POST("v1/upload-session")
    suspend fun uploadSession(@Body request: SessionUploadRequest): ApiResponse

    @POST("v1/get-presigned-url")
    suspend fun getPresignedUrl(@Body request: ChunkUploadRequest): PresignedUrlResponse

    @PUT
    suspend fun uploadChunkToUrl(
        @Url presignedUrl: String,
        @Body fileBytes: ByteArray
    ): Void

    @Multipart
    @POST("https://file.io/")
    suspend fun uploadFile(
        @Part file: MultipartBody.Part,
        @Query("expires") expires: String = "1w"
    ): Response<FileIoResponse>


    @POST("v1/notify-chunk-uploaded")
    suspend fun notifyChunkUploaded(@Body request: ChunkUploadNotificationRequest): ApiResponse
}