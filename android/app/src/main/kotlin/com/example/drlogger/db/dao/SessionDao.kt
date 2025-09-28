package com.example.drlogger.db.dao

import androidx.room.*
import com.example.drlogger.db.SessionEntity

@Dao
interface SessionDao {

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertSession(session: SessionEntity)

    @Query("SELECT * FROM sessions WHERE sessionId = :sessionId LIMIT 1")
    suspend fun getSession(sessionId: String): SessionEntity?

    @Query("UPDATE sessions SET endTime = :endTime, status = :status WHERE sessionId = :sessionId")
    suspend fun endSession(sessionId: String, endTime: Long, status: String = "completed")

    @Query("SELECT * FROM sessions")
    suspend fun getAll(): List<SessionEntity>
}