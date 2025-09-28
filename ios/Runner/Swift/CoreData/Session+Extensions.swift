//
//  Session+Extensions.swift
//  Runner
import Foundation
import CoreData

extension Session {
    func toMap() -> [String: Any?] {
        return [
            "sessionId": sessionId,
            "serverSessionId": serverSessionId,
            "patientId": patientId,
            "status": status,
            "startTime": startTime,
            "endTime": endTime
        ]
    }
    
    static func fromMap(_ map: [String: Any]) -> Session {
        let context = CoreDataManager.shared.context
        let session = Session(context: context)
        session.sessionId = map["sessionId"] as? String ?? UUID().uuidString
        session.serverSessionId = map["serverSessionId"] as? String ?? ""
        session.patientId = map["patientId"] as? String ?? "unknown"
        session.status = map["status"] as? String
        session.startTime = map["startTime"] as? String
        session.endTime = map["endTime"] as? String
        return session
    }
}
