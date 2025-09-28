//
//  ChunkUploadRequest.swift
//  Runner

import Foundation

struct ChunkUploadRequest: Codable {
    let sessionId: String
    let chunkNumber: Int
    let mimeType: String
}
