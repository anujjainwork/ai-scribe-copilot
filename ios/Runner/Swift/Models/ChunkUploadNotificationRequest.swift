//
//  ApiResponse 2.swift
//  Runner
//
//  Created by Anuj Jain on 28/09/25.
//


import Foundation

struct ChunkUploadNotificationRequest: Codable {
    let sessionId: String
    let chunkNumber: Int
}
