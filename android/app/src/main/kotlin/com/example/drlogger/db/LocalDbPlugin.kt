package com.example.drlogger.db



import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.room.Room
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class LocalDbPlugin(
    private val context: Context,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {

    private val methodChannel = MethodChannel(messenger, "drlogger/localdb")
    private val mainHandler = Handler(Looper.getMainLooper())

    private val db: AppDatabase = Room.databaseBuilder(
        context,
        AppDatabase::class.java,
        "drlogger-db"
    ).fallbackToDestructiveMigration().build()

    init {
        methodChannel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            // Session ops
            "insertSession" -> {
                val args = call.arguments as Map<*, *>
                CoroutineScope(Dispatchers.IO).launch {
                    val session = SessionEntity.fromMap(args as Map<String, Any>)
                    db.sessionDao().insertSession(session)
                    withContext(Dispatchers.Main) { result.success(true) }
                }
            }
            "getSessions" -> {
                CoroutineScope(Dispatchers.IO).launch {
                    val sessions = db.sessionDao().getAll()
                    val maps = sessions.map { it.toMap() }
                    withContext(Dispatchers.Main) { result.success(maps) }
                }
            }

            // AudioChunk ops
            "insertChunk" -> {
                val args = call.arguments as Map<*, *>
                CoroutineScope(Dispatchers.IO).launch {
                    val chunk = AudioChunkEntity.fromMap(args as Map<String, Any>)
                    db.audioChunkDao().insert(chunk)
                    withContext(Dispatchers.Main) { result.success(true) }
                }
            }
            "getChunksBySession" -> {
                val sessionId = call.argument<String>("sessionId")!!
                CoroutineScope(Dispatchers.IO).launch {
                    val chunks = db.audioChunkDao().getBySession(sessionId)
                    val maps = chunks.map { it.toMap() }
                    withContext(Dispatchers.Main) { result.success(maps) }
                }
            }

            "getUploadedChunksBySession" -> {
                val sessionId = call.argument<String>("sessionId")!!
                CoroutineScope(Dispatchers.IO).launch {
                    val chunks = db.audioChunkDao().getUploadedChunksBySession(sessionId)
                    val maps = chunks.map { it.toMap() }
                    withContext(Dispatchers.Main) { result.success(maps) }
                }
            }

            else -> result.notImplemented()
        }
    }
}
