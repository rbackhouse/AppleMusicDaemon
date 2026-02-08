//
//  Queue.swift
//  AppleMusicBridgeClient
//
//  Created by Richard Backhouse on 2/28/25.
//

import SwiftUI
import MusicKit

struct Queue: View {
    @StateObject private var client = WebSocketClient.shared
    @State private var selection: String?
    @State private var isHoveringPlayback = false

    var body: some View {
        VStack(spacing: 0) {
            // Now Playing Section with gradient background
            VStack(spacing: 0) {
                #if os(macOS)
                // Connection status bar
                HStack(spacing: 8) {
                    Image(systemName: client.isConnected ? "wifi" : "wifi.slash")
                        .foregroundColor(client.isConnected ? .green : .red)
                        .imageScale(.small)
                    Text(client.isConnected ? "Connected to \(client.url)" : "Disconnected")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
                #endif
                // Now playing card
                if let currentSong = client.currentSong {
                    VStack(spacing: 20) {
                        HStack(spacing: 16) {
                            if let artwork = currentSong.artwork {
                                ArtworkImage(artwork, width: 160)
                                    .cornerRadius(8)
                                    .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(currentSong.title)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                Text(currentSong.artistName)
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        
                        // Playback controls with better styling
                        VStack(spacing: 12) {
                            Slider(
                                value: $client.playbackTime,
                                in: 0...max(client.playbackDuration, 1)
                            )
                            .tint(.accentColor)
                            .disabled(client.playbackDuration == 0)
                            .scaleEffect(isHoveringPlayback ? 1.02 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: isHoveringPlayback)
                            .onHover { hovering in
                                isHoveringPlayback = hovering
                            }
                            
                            HStack {
                                Text(client.playbackTimeLabel)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(client.playbackDurationLabel)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 20)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("No song playing")
                            .font(.system(.title3, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
            #if os(iOS)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground),
                        Color(.systemBackground).opacity(0.8)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            #elseif os(macOS)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(nsColor: .controlBackgroundColor),
                        Color(nsColor: .controlBackgroundColor).opacity(0.8)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            #endif

            Divider()
            
            // Queue header
            HStack {
                Text("Song Queue")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                Text("\(client.queue.count) \(client.queue.count == 1 ? "song" : "songs")")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            #if os(iOS)
            .background(Color(.systemBackground).opacity(0.5))
            #elseif os(macOS)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            #endif

            // Queue list with improved styling
            if client.queue.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.3))
                    Text("Queue is empty")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List(selection: $selection) {
                        ForEach(client.queue.enumerated(), id: \.offset) { index, song in
                            QueueRowView(song: song, isCurrentlyPlaying: false)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .id(index)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .onChange(of: client.currentIndex) {
                        withAnimation {
                            proxy.scrollTo(client.currentIndex, anchor: .top)
                        }
                    }.onAppear {
                        withAnimation {
                            proxy.scrollTo(client.currentIndex, anchor: .top)
                        }
                    }
                }
            }
        }
        .navigationTitle("Queue")
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 500)
        #endif
    }
}

// Separate row view component for better organization
struct QueueRowView: View {
    @StateObject private var client = WebSocketClient.shared

    let song: Song
    let isCurrentlyPlaying: Bool // Add this parameter
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 14) {
            // Artwork
            if let artwork = song.artwork {
                ArtworkImage(artwork, width: 52)
                    .cornerRadius(6)
                    .shadow(color: Color.black.opacity(isHovering ? 0.2 : 0.1), radius: 4, x: 0, y: 2)
            }
            if client.currentSong != nil {
                if song.title == client.currentSong!.title &&
                    song.albumTitle == client.currentSong!.albumTitle &&
                    song.artistName == client.currentSong!.artistName && client.playbackStatus == .playing {
                    PlayingIndicatorView()
                        .padding(6)
                        #if os(iOS)
                        .background(
                            Circle()
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                        )
                        #elseif os(macOS)
                        .background(
                            Circle()
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                        )
                        #endif
                        .offset(x: 4, y: 4)
                }
            }
            
            // Song details
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.system(.body, design: .rounded))
                    .lineLimit(1)
                
                Text(song.artistName)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 8)
            
            // Hover indicator
            if isHovering {
                Image(systemName: "ellipsis")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color.secondary.opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                // Remove from queue
            } label: {
                Label("Remove from Queue", systemImage: "trash")
            }
            
            Divider()
            
            Button {
                // Show info
            } label: {
                Label("Song Info", systemImage: "info.circle")
            }
        }
    }
}

struct PlayingIndicatorView: View {
    @State private var animateBar1 = false
    @State private var animateBar2 = false
    @State private var animateBar3 = false
    
    var body: some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.accentColor)
                .frame(width: 3, height: animateBar1 ? 14 : 6)
            
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.accentColor)
                .frame(width: 3, height: animateBar2 ? 16 : 8)
            
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.accentColor)
                .frame(width: 3, height: animateBar3 ? 12 : 7)
        }
        .frame(width: 16, height: 16)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                animateBar1.toggle()
            }
            withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true).delay(0.1)) {
                animateBar2.toggle()
            }
            withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true).delay(0.2)) {
                animateBar3.toggle()
            }
        }
    }
}
