//
//  BonjourService.swift
//  AppleMusicBridge
//
//  Created by Richard Backhouse on 2/24/25.
//

import Foundation
import Network
import Combine

class BonjourService : ObservableObject {
    @Published var serviceName: String = ""

    var listenerQ: NWListener? = nil
    
    func start() -> NWListener? {
        print("listener will start")
        guard let listener = try? NWListener(using: .tcp, on: 9991) else { return nil }
        listener.stateUpdateHandler = { newState in
            print("listener did change state, new: \(newState)")
        }
        listener.newConnectionHandler = { connection in
            connection.cancel()
        }
        listener.service = .init(name: "Apple Music Daemon", type: "_amb._tcp")
        listener.serviceRegistrationUpdateHandler = { change in
            switch change {
            case .add(let endpoint):
                switch endpoint {
                case let .service(name, type, domain, interface):
                    print("service name: \(name) type: \(type) domain: \(domain) interface: \(interface?.name ?? "nil")")
                    self.serviceName = name
                default:
                    break
                }
            case .remove(_):
                break
            @unknown default:
                break
            }
        }
        listener.start(queue: .main)
        return listener
    }
    
    func stop(listener: NWListener) {
        print("listener will stop")
        listener.stateUpdateHandler = nil
        listener.cancel()
    }
    
    func startStop() {
        if let listener = self.listenerQ {
            self.listenerQ = nil
            self.stop(listener: listener)
        } else {
            self.listenerQ = self.start()
        }
    }
}
