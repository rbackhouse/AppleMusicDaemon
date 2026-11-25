//
//  AMDConfig.swift
//  AppleMusicDaemonClient
//

import Foundation
import SwiftData

@Model
public class AMDConfig : Identifiable, Equatable {
    public var id: UUID
    var name: String
    var host: String
    var port: Int
    var token: String?
    
    init(name: String, host: String, port: Int, token: String? = nil) {
        id = UUID()
        self.host = host
        self.port = port
        self.name = name
        self.token = token
    }
}
