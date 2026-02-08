//
//  Connections.swift
//  AppleMusicDaemonClient
//
//  Created by Richard Backhouse on 12/29/25.
//

import SwiftUI

struct Connections: View {
    @StateObject private var bonjourService = BonjourService()
    @Environment(\.dismiss) private var dismiss
    @State private var isScanning = false
    @Binding var server: AMDConfig

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("AMD Connections")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Discover and connect to AMD servers")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                .padding(.horizontal)
                
                // Content
                ScrollView {
                    LazyVStack(spacing: 24) {
                        // Discovered Servers Section
                        serverSection(
                            title: "Discovered Servers",
                            servers: getAllServers(),
                            emptyMessage: isScanning ? "Scanning for servers..." : "No servers found"
                        )
                        
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Button(action: rescanServers) {
                            HStack {
                                Image(systemName: isScanning ? "arrow.clockwise" : "arrow.clockwise.circle.fill")
                                    .rotationEffect(.degrees(isScanning ? 360 : 0))
                                    .animation(isScanning ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isScanning)
                                Text("Rescan")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isScanning)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .fixedSize()
        }
        .onAppear {
            startInitialScan()
        }
    }
    
    // MARK: - Helper Views

    @ViewBuilder
    private func serverSection(title: String, servers: [AMDConfig], emptyMessage: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if title.contains("Discovered") && !servers.isEmpty {
                    Text("\(servers.count) found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                }
            }
            
            if servers.isEmpty {
                emptyStateView(message: emptyMessage)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(servers, id: \.id) { server in
                        ServerRow(server: server) {
                            selectServer(server)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        #if os(iOS)
        .background(Color(.systemBackground))
        #elseif os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
        #endif
        .cornerRadius(12)
    }

    @ViewBuilder
    private func emptyStateView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "wifi.circle")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Helper Methods

    private func getAllServers() -> [AMDConfig] {
        let servers = bonjourService.servers
        return servers
    }

    private func selectServer(_ selectedServer: AMDConfig) {
        if server.host != "" {
            print("Disconnecting from \(server.host)")
            WebSocketClient.shared.disconnect()
        }
        server = selectedServer
        print("Connecting to \(server.host)")
        WebSocketClient.shared.connect(url: URL(string: "ws://\(server.host):9992/amdsocket")!)
        dismiss()
    }

    private func rescanServers() {
        withAnimation {
            isScanning = true
        }
        
        bonjourService.servers.removeAll()
        bonjourService.startStop()
        bonjourService.startStop()
        
        // Simulate scanning duration
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                isScanning = false
            }
        }
    }

    private func startInitialScan() {
        bonjourService.startStop()
    }
}

// MARK: - Supporting Views

struct ServerRow: View {
    let server: AMDConfig
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Server Icon
                Image(systemName: "server.rack")
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                
                // Server Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(server.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(server.host)
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(verbatim: "9992")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                }
                Spacer()
                
                // Connection Indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            #if os(iOS)
            .background(Color(.systemBackground))
            #elseif os(macOS)
            .background(Color(nsColor: .controlBackgroundColor))
            #endif
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
