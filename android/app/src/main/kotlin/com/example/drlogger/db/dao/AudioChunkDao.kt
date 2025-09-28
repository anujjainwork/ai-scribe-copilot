package com.example.drlogger.db.dao

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Upsert
import com.example.drlogger.db.AudioChunkEntity

@Dao
interface AudioChunkDao {

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(chunk: AudioChunkEntity)

    @Upsert()
    suspend fun update(chunk: AudioChunkEntity)

    @Query("SELECT * FROM audio_chunks WHERE sessionId = :sessionId ORDER BY chunkNumber ASC")
    suspend fun getBySession(sessionId: String): List<AudioChunkEntity>

    @Query("UPDATE audio_chunks SET status = :status WHERE audioId = :audioId")
    suspend fun updateStatus(audioId: String, status: String)

    @Query("SELECT * FROM audio_chunks WHERE status LIKE 'pending%' OR status LIKE 'retrying%'")
    suspend fun getPendingOrRetrying(): List<AudioChunkEntity>

    @Query("SELECT * FROM audio_chunks WHERE sessionId = :sessionId AND status = 'uploaded' ORDER BY chunkNumber ASC")
    suspend fun getUploadedChunksBySession(sessionId: String): List<AudioChunkEntity>

    @Query("""
    UPDATE audio_chunks 
    SET status = :status, publicUrl = :publicUrl 
    WHERE audioId = :audioId
""")
    suspend fun updateStatusAndPublicUrl(audioId: String, status: String, publicUrl: String)

}