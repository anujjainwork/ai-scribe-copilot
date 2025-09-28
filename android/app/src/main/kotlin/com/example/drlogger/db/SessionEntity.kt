package com.example.drlogger.db

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "sessions")
data class SessionEntity(
    @PrimaryKey val sessionId: String,
    val serverSessionId: String,
    val patientId: String,
    val status: String,
    val startTime: Long,
    val endTime: Long?
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "sessionId" to sessionId,
        "serverSessionId" to serverSessionId,
        "patientId" to patientId,
        "status" to status,
        "startTime" to startTime,
        "endTime" to endTime
    )

    companion object {
        fun fromMap(map: Map<String, Any?>): SessionEntity {
            return SessionEntity(
                sessionId = map["sessionId"] as String,
                serverSessionId = map["serverSessionId"] as String,
                patientId = map["patientId"] as String,
                status = map["status"] as String,
                startTime = (map["startTime"] as Number).toLong(),
                endTime = (map["endTime"] as? Number)?.toLong()
            )
        }
    }
}