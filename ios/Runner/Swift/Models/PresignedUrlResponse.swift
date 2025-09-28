//
//  PresignedUrlResponse.swift
//  Runner
//
//  Created by Anuj Jain on 28/09/25.
//

import Foundation

struct PresignedUrlResponse: Codable {
    let url: String
    let gcsPath: String?
    let publicUrl: String?
}
