//
//  LocalDbPlugin.swift
//  Runner


import Flutter
import UIKit
import CoreData

public class LocalDbPlugin: NSObject, FlutterPlugin {
    
    private var methodChannel: FlutterMethodChannel
    
    init(messenger: FlutterBinaryMessenger) {
        self.methodChannel = FlutterMethodChannel(name: "drlogger/localdb", binaryMessenger: messenger)
        super.init()
        self.methodChannel.setMethodCallHandler(handle)
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = LocalDbPlugin(messenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: instance.methodChannel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        // Session ops
        case "insertSession":
            if let args = call.arguments as? [String: Any] {
                insertSession(args, result: result)
            }
        case "getSessions":
            getSessions(result: result)
            
        // AudioChunk ops
        case "insertChunk":
            if let args = call.arguments as? [String: Any] {
                insertChunk(args, result: result)
            }
        case "getChunksBySession":
            if let args = call.arguments as? [String: Any],
               let sessionId = args["sessionId"] as? String {
                getChunksBySession(sessionId, result: result)
            }
        
        case "getUploadedChunksBySession":
            if let args = call.arguments as? [String: Any],
               let sessionId = args["sessionId"] as? String {
                getUploadedChunksBySession(sessionId, result: result)
            }
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    
    // MARK: - Session Methods
    private func insertSession(_ map: [String: Any], result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .background).async {
            _ = Session.fromMap(map)
            CoreDataManager.shared.saveContext()
            DispatchQueue.main.async { result(true) }
        }
    }

    private func getSessions(result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .background).async {
            let fetch: NSFetchRequest<Session> = Session.fetchRequest()
            let sessions = (try? CoreDataManager.shared.context.fetch(fetch)) ?? []
            let maps = sessions.map { $0.toMap() }
            DispatchQueue.main.async { result(maps) }
        }
    }

    // MARK: - AudioChunk Methods
    private func insertChunk(_ map: [String: Any], result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .background).async {
            _ = AudioChunk.fromMap(map)
            CoreDataManager.shared.saveContext()
            DispatchQueue.main.async { result(true) }
        }
    }

    private func getChunksBySession(_ sessionId: String, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .background).async {
            let fetch: NSFetchRequest<AudioChunk> = AudioChunk.fetchRequest()
            fetch.predicate = NSPredicate(format: "sessionId == %@", sessionId)
            fetch.sortDescriptors = [NSSortDescriptor(key: "chunkNumber", ascending: true)]
            let chunks = (try? CoreDataManager.shared.context.fetch(fetch)) ?? []
            let maps = chunks.map { $0.toMap() }
            DispatchQueue.main.async { result(maps) }
        }
    }
    
    private func getUploadedChunksBySession(_ sessionId: String, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .background).async {
            let fetch: NSFetchRequest<AudioChunk> = AudioChunk.fetchRequest()
            // Filter by sessionId AND status = "uploaded"
            fetch.predicate = NSPredicate(format: "sessionId == %@ AND status == %@", sessionId, "uploaded")
            fetch.sortDescriptors = [NSSortDescriptor(key: "chunkNumber", ascending: true)]
            
            let chunks = (try? CoreDataManager.shared.context.fetch(fetch)) ?? []
            let maps = chunks.map { $0.toMap() }
            
            DispatchQueue.main.async { result(maps) }
        }
    }

}
