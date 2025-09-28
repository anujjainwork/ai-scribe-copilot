package com.example.drlogger.db

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import com.example.drlogger.db.dao.AudioChunkDao
import com.example.drlogger.db.dao.SessionDao

@Database(
    entities = [AudioChunkEntity::class, SessionEntity::class],
    version = 1,
    exportSchema = false
)
abstract class AppDatabase : RoomDatabase() {

    abstract fun audioChunkDao(): AudioChunkDao
    abstract fun sessionDao(): SessionDao

    companion object {
        @Volatile private var instance: AppDatabase? = null

        fun getDatabase(context: Context): AppDatabase =
            instance ?: synchronized(this) {
                instance ?: Room.databaseBuilder(
                    context.applicationContext,
                    AppDatabase::class.java,
                    "localdb.db"
                ).build().also { instance = it }
            }
    }
}
