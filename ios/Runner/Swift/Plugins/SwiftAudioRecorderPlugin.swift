//
// SwiftAudioRecorderPlugin.swift
// Runner
//

import Flutter
import UIKit
import AVFoundation
import Speech
import CoreData

public class SwiftAudioRecorderPlugin: NSObject, FlutterPlugin {
    private var methodChannel: FlutterMethodChannel?
    private var recorderEventSink: FlutterEventSink?
    private var transcriptionEventSink: FlutterEventSink?

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    private var activeSessionId: String?
    private var chunkCounter = 0

    // Buffer accumulation for larger chunks
    private var bufferAccumulator: AVAudioPCMBuffer?
    private var accumulatedFrames = 0
    private var buffersPerChunk = 1
    private var desiredChunkMs: Double = 300
    
    private var lastSentTranscription = ""

    // Upload queue (serial background queue for per-chunk uploads)
    private let uploadQueue = DispatchQueue(label: "audio.upload.queue", qos: .background)

    // Pause state flags
    private var isRecordingPaused = false  // Tracks whether recording is paused
    private var isEngineRunning: Bool {
        return audioEngine?.isRunning ?? false
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "drlogger/recorder", binaryMessenger: registrar.messenger())
        let recorderEventChannel = FlutterEventChannel(name: "drlogger/recorder_events", binaryMessenger: registrar.messenger())
        let transcriptionEventChannel = FlutterEventChannel(name: "drlogger/transcription_events", binaryMessenger: registrar.messenger())

        let instance = SwiftAudioRecorderPlugin()
        instance.methodChannel = channel

        registrar.addMethodCallDelegate(instance, channel: channel)
        recorderEventChannel.setStreamHandler(StreamHandlerWrapper(
            onListen: { events in instance.recorderEventSink = events },
            onCancel: { instance.recorderEventSink = nil }
        ))
        transcriptionEventChannel.setStreamHandler(StreamHandlerWrapper(
            onListen: { events in instance.transcriptionEventSink = events },
            onCancel: { instance.transcriptionEventSink = nil }
        ))
    }

    // MARK: - Flutter Method Calls
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startRecording":
            guard let args = call.arguments as? [String: Any],
                  let sessionId = args["sessionId"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing sessionId", details: nil))
                return
            }
            desiredChunkMs = args["chunkSizeMs"] as? Double ?? 300
            startRecording(sessionId: sessionId)
            result(nil)
        case "pauseRecording":
            pauseRecording()
            result(nil)
        case "resumeRecording":
            resumeRecording()
            result(nil)
        case "stopRecording":
            stopRecording()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Recording Lifecycle
    private func startRecording(sessionId: String) {
        activeSessionId = sessionId
        chunkCounter = 0
        bufferAccumulator = nil
        accumulatedFrames = 0

        configureAudioSession()
        setupAudioEngine()
        startAudioEngine()

        // Insert session into local DB (CoreData)
        insertSessionToDb(sessionId: sessionId, serverSessionId: nil, patientId: nil)

        // Create session on server (best-effort). We send minimal data; adjust fields as needed.
        createSessionOnServer(sessionId: sessionId)
    }

    // MARK: - Safe Pause / Resume

    // Pause recording safely
    private func pauseRecording() {
        guard !isRecordingPaused else { return } // Already paused
        audioEngine?.pause()                       // Pause the audio engine
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])

        isRecordingPaused = true

        if let sessionId = activeSessionId {
            sendStatusEvent(sessionId: sessionId, status: "paused")
        }
    }

    // Resume recording safely
    private func resumeRecording() {
        guard isRecordingPaused else { return } // Already running

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord,
                                    mode: .measurement,
                                    options: [.mixWithOthers, .allowBluetooth, .defaultToSpeaker])
            try session.setActive(true, options: [.notifyOthersOnDeactivation])

            if !(audioEngine?.isRunning ?? false) {
                try audioEngine?.start()
            }

            isRecordingPaused = false

            if let sessionId = activeSessionId {
                sendStatusEvent(sessionId: sessionId, status: "resumed")
            }
        } catch {
            print("Failed to resume audio engine: \(error.localizedDescription)")
        }
    }

    private func stopRecording() {
        audioEngine?.stop()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        guard let sessionId = activeSessionId else { return }

        // Send final "lastChunk" event to Flutter
        let lastChunkId = UUID().uuidString
        let timestampMs = Int(Date().timeIntervalSince1970 * 1000)
        let lastChunkMap: [String: Any] = [
            "type": "chunk",
            "sessionId": sessionId,
            "audioId": lastChunkId,
            "chunkNumber": chunkCounter + 1,
            "filePath": "",
            "timestampMs": timestampMs,
            "amplitude": 0.0,
            "lastChunk": true
        ]
        recorderEventSink?(lastChunkMap)

        insertAudioChunkToDb(sessionId: sessionId,
                             chunkNumber: chunkCounter + 1,
                             filePath: "",
                             durationMs: 0,
                             amplitude: 0.0,
                             status: "completed")

        markSessionCompletedInDb(sessionId: sessionId)

        activeSessionId = nil
        chunkCounter = 0
    }

    // MARK: - Audio Engine + Tap
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord,
                                    mode: .measurement,
                                    options: [.mixWithOthers, .allowBluetooth, .defaultToSpeaker])
            try session.setActive(true, options: [.notifyOthersOnDeactivation])

            // Background recording enabled
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(handleInterruption),
                                                   name: AVAudioSession.interruptionNotification,
                                                   object: session)
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(handleRouteChange),
                                                   name: AVAudioSession.routeChangeNotification,
                                                   object: session)

        } catch {
            print("AudioSession error: \(error.localizedDescription)")
        }
    }

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true
        recognitionRequest?.requiresOnDeviceRecognition = true

        guard let inputNode = audioEngine?.inputNode else { return }
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)

        let bufferDurationMs = Double(1024) / format.sampleRate * 1000
        buffersPerChunk = Int(ceil(desiredChunkMs / bufferDurationMs))

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] (buffer, _) in
            guard let self = self else { return }

            self.recognitionRequest?.append(buffer)

            if self.bufferAccumulator == nil {
                self.bufferAccumulator = AVAudioPCMBuffer(pcmFormat: buffer.format,
                                                          frameCapacity: AVAudioFrameCount(self.buffersPerChunk * Int(buffer.frameLength)))
            }

            let accBuf = self.bufferAccumulator!
            let startFrame = accBuf.frameLength
            let frameCount = buffer.frameLength
            for ch in 0..<Int(buffer.format.channelCount) {
                if let src = buffer.floatChannelData?[ch], let dst = accBuf.floatChannelData?[ch] {
                    memcpy(dst + Int(startFrame), src, Int(frameCount) * MemoryLayout<Float>.size)
                }
            }
            accBuf.frameLength += frameCount
            self.accumulatedFrames += 1

            if self.accumulatedFrames >= self.buffersPerChunk {
                self.sendChunk(accBuf)
                self.bufferAccumulator = nil
                self.accumulatedFrames = 0
            }
        }

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest!) { [weak self] result, error in
            guard let self = self else { return }
            if let result = result {
                let newText = result.bestTranscription.formattedString

                if newText != self.lastSentTranscription {
                    let delta = newText.replacingOccurrences(of: self.lastSentTranscription, with: "")
                    self.lastSentTranscription = newText

                    self.transcriptionEventSink?([
                        "sessionId": self.activeSessionId ?? "",
                        "chunkNumber": self.chunkCounter,
                        "partialText": delta,
                        "isFinal": result.isFinal
                    ])
                }
            }
        }
    }

    private func startAudioEngine() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            try audioEngine?.start()
        } catch {
            print("Error starting audio engine: \(error.localizedDescription)")
        }
    }

    // MARK: - Chunk Sending (writes file, enqueues upload flow)
    private func sendChunk(_ buffer: AVAudioPCMBuffer) {
        chunkCounter += 1
        let audioId = UUID().uuidString
        let timestampMs = Int(Date().timeIntervalSince1970 * 1000)

        var peak: Float = 0
        if let data = buffer.floatChannelData?[0] {
            for i in 0..<Int(buffer.frameLength) { peak = max(peak, fabsf(data[i])) }
        }

        let filePath = NSTemporaryDirectory() + "\(audioId).pcm"
        let url = URL(fileURLWithPath: filePath)
        if let audioFile = try? AVAudioFile(forWriting: url, settings: buffer.format.settings) {
            try? audioFile.write(from: buffer)
        }

        // Save chunk in local DB as pending
        if let sessionId = activeSessionId {
            insertAudioChunkToDb(sessionId: sessionId,
                                 chunkNumber: chunkCounter,
                                 filePath: filePath,
                                 durationMs: Int(buffer.frameLength),
                                 amplitude: Double(peak),
                                 status: "pending")

            // Fire recorder event to Flutter UI
            let map: [String: Any] = [
                "type": "chunk",
                "sessionId": sessionId,
                "audioId": audioId,
                "chunkNumber": self.chunkCounter,
                "filePath": filePath,
                "timestampMs": timestampMs,
                "amplitude": Double(peak),
                "lastChunk": false
            ]
            recorderEventSink?(map)

            // Enqueue the upload flow for this chunk (serial queue)
            uploadQueue.async { [weak self] in
                guard let self = self else { return }
                self.uploadFlowForChunk(sessionId: sessionId, chunkNumber: self.chunkCounter, filePath: filePath)
            }
        }
    }

    // MARK: - Upload Flow: get presigned url -> upload -> notify -> update CoreData
    /// Orchestrates the full server flow for a single chunk.
    private func uploadFlowForChunk(sessionId: String, chunkNumber: Int, filePath: String) {
        // Build presigned URL request
        let mimeType = "audio/pcm" // adjust if you change encoding
        let presignedReq = ChunkUploadRequest(sessionId: sessionId, chunkNumber: chunkNumber, mimeType: mimeType)

        // 1) Get presigned URL
        let semaphore = DispatchSemaphore(value: 0)
        var presignedUrlResult: Result<PresignedUrlResponse, Error>?
        ApiService.shared.getPresignedUrl(request: presignedReq) { result in
            presignedUrlResult = result
            semaphore.signal()
        }
        // Wait for network response (we're already on background queue)
        _ = semaphore.wait(timeout: .now() + 30) // 30s timeout - adjust if needed

        switch presignedUrlResult {
        case .success(let presigned):
            // 2) Read file bytes
            guard let fileData = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
                // mark failed in DB
                self.updateChunkStatusInDb(sessionId: sessionId, chunkNumber: chunkNumber, status: "file_read_error")
                return
            }

            // 3) Upload chunk bytes to presigned URL with basic retry/backoff
            let maxAttempts = 3
            var attempt = 0
            var uploadSuccess = false
            while attempt < maxAttempts && !uploadSuccess {
                let uploadSemaphore = DispatchSemaphore(value: 0)
                ApiService.shared.uploadChunkToUrl(url: presigned.url, fileBytes: fileData) { result in
                    switch result {
                    case .success:
                        uploadSuccess = true
                    case .failure(let err):
                        print("Chunk upload attempt \(attempt + 1) failed: \(err.localizedDescription)")
                    }
                    uploadSemaphore.signal()
                }
                _ = uploadSemaphore.wait(timeout: .now() + 60) // wait for upload result (60s)
                if !uploadSuccess {
                    // simple backoff
                    Thread.sleep(forTimeInterval: Double(1 << attempt)) // 1s, 2s, 4s
                }
                attempt += 1
            }

            if !uploadSuccess {
                // mark failed in DB
                self.updateChunkStatusInDb(sessionId: sessionId, chunkNumber: chunkNumber, status: "upload_failed")
                return
            }

            // 4) Notify server that chunk is uploaded
            let notifyReq = ChunkUploadNotificationRequest(sessionId: sessionId, chunkNumber: chunkNumber)
            let notifySemaphore = DispatchSemaphore(value: 0)
            var notifyResult: Result<ApiResponse, Error>?
            ApiService.shared.notifyChunkUploaded(request: notifyReq) { result in
                notifyResult = result
                notifySemaphore.signal()
            }
            _ = notifySemaphore.wait(timeout: .now() + 30)

            switch notifyResult {
            case .success(let apiResp):
                // Success: mark chunk uploaded
                self.updateChunkStatusInDb(sessionId: sessionId, chunkNumber: chunkNumber, status: "uploaded")
                print("Chunk \(chunkNumber) uploaded and notified. Server message: \(apiResp.message)")
            case .failure(let error):
                // Notification failed: mark pending or failed as per your strategy
                print("Notify failed for chunk \(chunkNumber): \(error.localizedDescription)")
                self.updateChunkStatusInDb(sessionId: sessionId, chunkNumber: chunkNumber, status: "notify_failed")
            case .none:
                self.updateChunkStatusInDb(sessionId: sessionId, chunkNumber: chunkNumber, status: "notify_timeout")
            }
        case .failure(let error):
            print("Failed to get presigned URL for chunk \(chunkNumber): \(error.localizedDescription)")
            self.updateChunkStatusInDb(sessionId: sessionId, chunkNumber: chunkNumber, status: "presigned_failed")
        case .none:
            print("Presigned URL request timed out for chunk \(chunkNumber)")
            self.updateChunkStatusInDb(sessionId: sessionId, chunkNumber: chunkNumber, status: "presigned_timeout")
        }
    }

    // MARK: - Create session on server (best-effort)
    /// Calls ApiService.uploadSession with a minimal SessionUploadRequest.
    /// Adjust fields (patientId, userId, templateId) to provide actual values from your Flutter args.
    private func createSessionOnServer(sessionId: String) {
        // Build a minimal request; replace "unknown" with real details if available
        let iso = ISO8601DateFormatter().string(from: Date())
        let req = SessionUploadRequest(patientId: "unknown",
                                       userId: "unknown",
                                       patientName: "unknown",
                                       status: "recording",
                                       startTime: iso,
                                       templateId: "unknown")

        ApiService.shared.uploadSession(request: req) { result in
            switch result {
            case .success(let apiResp):
                // If backend returns a server-session-id in message, store it locally.
                // Adjust: if your backend returns a different field, parse accordingly.
                print("Upload session response success: \(apiResp.message)")
                self.updateSessionServerId(sessionId: sessionId, serverId: apiResp.message)
            case .failure(let error):
                print("Failed to create session on server: \(error.localizedDescription)")
                // we continue locally; uploads can still happen (they use client sessionId)
            }
        }
    }

    // MARK: - Helpers: CoreData updates for session and chunk statuses
    private func updateSessionServerId(sessionId: String, serverId: String) {
        DispatchQueue.global(qos: .background).async {
            let context = CoreDataManager.shared.context
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

            let fetch: NSFetchRequest<Session> = Session.fetchRequest()
            fetch.predicate = NSPredicate(format: "sessionId == %@", sessionId)

            if let existing = try? context.fetch(fetch).first {
                existing.serverSessionId = serverId
                CoreDataManager.shared.saveContext()
            }
        }
    }

    private func updateChunkStatusInDb(sessionId: String, chunkNumber: Int, status: String) {
        DispatchQueue.global(qos: .background).async {
            let context = CoreDataManager.shared.context
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

            let audioId = "\(sessionId)-\(chunkNumber)"
            let fetch: NSFetchRequest<AudioChunk> = AudioChunk.fetchRequest()
            fetch.predicate = NSPredicate(format: "audioId == %@", audioId)

            if let existing = try? context.fetch(fetch).first {
                existing.status = status
                existing.createdAt = ISO8601DateFormatter().string(from: Date())
                CoreDataManager.shared.saveContext()
            }
        }
    }

    // MARK: - Interruption Handling (Phone Calls, Siri, etc.)
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue),
              let sessionId = activeSessionId else { return }

        switch type {
        case .began:
            // Pause recording when interruption begins (e.g., incoming call)
            pauseRecording()
            sendStatusEvent(sessionId: sessionId, status: "paused")
        case .ended:
            // Resume recording if possible when interruption ends
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    try? AVAudioSession.sharedInstance().setActive(true)
                    resumeRecording()
                    sendStatusEvent(sessionId: sessionId, status: "resumed")
                }
            }
        @unknown default:
            break
        }
    }

    // MARK: - Audio Route Change Handling (Bluetooth, Headphones)
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue),
              let sessionId = activeSessionId else { return }

        switch reason {
        case .oldDeviceUnavailable:
            // E.g., headphone unplugged
            pauseRecording()
            sendStatusEvent(sessionId: sessionId, status: "paused_due_to_route_change")
        case .newDeviceAvailable, .routeConfigurationChange:
            // E.g., Bluetooth connected or other route change
            // Restart engine to avoid stopping audio input
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                try? AVAudioSession.sharedInstance().setActive(true)
                self.resumeRecording()
                self.sendStatusEvent(sessionId: sessionId, status: "resumed_after_route_change")
            }
        default:
            break
        }
    }

    private func sendStatusEvent(sessionId: String, status: String) {
        let map: [String: Any] = [
            "type": "status",
            "sessionId": sessionId,
            "status": status
        ]
        recorderEventSink?(map)
    }

    // MARK: - Local DB / CoreData
    private func insertSessionToDb(sessionId: String, serverSessionId: String?, patientId: String?, status: String = "active") {
        DispatchQueue.global(qos: .background).async {
            let context = CoreDataManager.shared.context
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

            let fetch: NSFetchRequest<Session> = Session.fetchRequest()
            fetch.predicate = NSPredicate(format: "sessionId == %@", sessionId)

            if let existing = try? context.fetch(fetch).first {
                existing.serverSessionId = serverSessionId ?? ""
                existing.patientId = patientId ?? "unknown"
                existing.status = status
                existing.endTime = ISO8601DateFormatter().string(from: Date())
            } else {
                let session = Session(context: context)
                session.sessionId = sessionId
                session.serverSessionId = serverSessionId ?? ""
                session.patientId = patientId ?? "unknown"
                session.status = status
                session.startTime = ISO8601DateFormatter().string(from: Date())
            }

            CoreDataManager.shared.saveContext()
        }
    }

    private func insertAudioChunkToDb(sessionId: String, chunkNumber: Int, filePath: String, durationMs: Int, amplitude: Double, status: String = "pending") {
        DispatchQueue.global(qos: .background).async {
            let context = CoreDataManager.shared.context
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

            let audioId = "\(sessionId)-\(chunkNumber)"
            let fetch: NSFetchRequest<AudioChunk> = AudioChunk.fetchRequest()
            fetch.predicate = NSPredicate(format: "audioId == %@", audioId)

            if let existing = try? context.fetch(fetch).first {
                existing.filePath = filePath
                existing.durationMs = Int32(durationMs)
                existing.status = status
                existing.createdAt = ISO8601DateFormatter().string(from: Date())
            } else {
                let chunk = AudioChunk(context: context)
                chunk.audioId = audioId
                chunk.sessionId = sessionId
                chunk.chunkNumber = Int32(chunkNumber)
                chunk.filePath = filePath
                chunk.durationMs = Int32(durationMs)
                chunk.amplitude = amplitude
                chunk.status = status
                chunk.createdAt = ISO8601DateFormatter().string(from: Date())
            }

            CoreDataManager.shared.saveContext()
        }
    }

    private func markSessionCompletedInDb(sessionId: String) {
        DispatchQueue.global(qos: .background).async {
            let context = CoreDataManager.shared.context
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

            let fetch: NSFetchRequest<Session> = Session.fetchRequest()
            fetch.predicate = NSPredicate(format: "sessionId == %@", sessionId)

            if let session = try? context.fetch(fetch).first {
                session.endTime = ISO8601DateFormatter().string(from: Date())
                session.status = "completed"
                CoreDataManager.shared.saveContext()
            }
        }
    }
}

// MARK: - StreamHandlerWrapper
class StreamHandlerWrapper: NSObject, FlutterStreamHandler {
    private let onListen: (FlutterEventSink?) -> Void
    private let onCancel: () -> Void

    init(onListen: @escaping (FlutterEventSink?) -> Void,
         onCancel: @escaping () -> Void) {
        self.onListen = onListen
        self.onCancel = onCancel
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        onListen(events); return nil
    }
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        onCancel(); return nil
    }
}
