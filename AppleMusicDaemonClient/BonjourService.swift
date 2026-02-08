//
//  BonjourService.swift
//  AppleMusicBridgeClient
//
//  Created by Richard Backhouse on 2/24/25.
//

import Foundation
import Network
import Combine

class BonjourService : ObservableObject {
    @Published var servers: [AMDConfig] = []

    var browserQ: NWBrowser? = nil
    
    func start() -> NWBrowser {
        //print("browser will start")
        let descriptor = NWBrowser.Descriptor.bonjour(type: "_amb._tcp", domain: "local.")
        let browser = NWBrowser(for: descriptor, using: .tcp)
        browser.stateUpdateHandler = { newState in
            //print("browser did change state, new: \(newState)")
        }
        browser.browseResultsChangedHandler = { updated, changes in
            //print("browser results did change:")
            for change in changes {
                switch change {
                case .added(let result):
                    BonjourResolver.resolve(endpoint: result.endpoint) { result in
                        switch result {
                        case .success(let service):
                            let split = service.0.components(separatedBy: ".")
                            var name = split[0]
                            name = name.replacingOccurrences(of: "\\032", with: " ")
                            let server = AMDConfig(name: name, host: service.1, port: service.2)
                            self.servers.append(server)
                        case .failure(let error):
                            print("did not resolve, error: \(error)")
                        }
                    }
                case .removed(let result):
                    print("- \(result.endpoint)")
                case .changed(old: let old, new: let new, flags: _):
                    print("± \(old.endpoint) \(new.endpoint)")
                case .identical:
                    fallthrough
                @unknown default:
                    print("?")
                }
            }
        }
        browser.start(queue: .main)
        return browser
    }
    
    func stop(browser: NWBrowser) {
        print("browser will stop")
        browser.stateUpdateHandler = nil
        browser.cancel()
    }
    
    func startStop() {
        if let browser = self.browserQ {
            self.browserQ = nil
            self.stop(browser: browser)
        } else {
            self.browserQ = self.start()
        }
    }
}
