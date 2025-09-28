//
//  SessionUploadRequest.swift
//  Runner
//
//  Created by Anuj Jain on 28/09/25.
//

import Foundation

struct SessionUploadRequest: Codable {
    let patientId: String
    let userId: String
    let patientName: String
    let status: String
    let startTime: String
    let templateId: String
}
