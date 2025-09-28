//
//  AudioChunk+Extensions.swift
//  Runner
//
import Foundation
import CoreData

extension AudioChunk {
    func toMap() -> [String: Any?] {
        return [
            "audioId": audioId,
            "sessionId": sessionId,
            "chunkNumber": Int(chunkNumber),
            "filePath": filePath,
            "durationMs": Int(durationMs),
            "status": status,
            "createdAt": createdAt,
            "gcsPath": gcsPath,
            "publicUrl": publicUrl
        ]
    }
    
    static func fromMap(_ map: [String: Any]) -> AudioChunk {
        let context = CoreDataManager.shared.context
        let chunk = AudioChunk(context: context)
        chunk.audioId = map["audioId"] as? String ?? UUID().uuidString
        chunk.sessionId = map["sessionId"] as? String ?? ""
        chunk.chunkNumber = Int32(map["chunkNumber"] as? Int ?? 0)
        chunk.filePath = map["filePath"] as? String ?? ""
        chunk.durationMs = Int32(map["durationMs"] as? Int ?? 0)
        chunk.status = map["status"] as? String ?? "pending"
        chunk.createdAt = map["createdAt"] as? String
        chunk.gcsPath = map["gcsPath"] as? String
        chunk.publicUrl = map["publicUrl"] as? String
        return chunk
    }
}

