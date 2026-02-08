//
//  PlaylistDetailView.swift
//  AppleMusicBridgeClient
//
//  Created by Richard Backhouse on 3/1/25.
//

import SwiftUI
import MusicKit

struct PlaylistDetailView: View {
    let playlist: Playlist
    @State private var tracks: MusicItemCollection<Track>?
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Fixed Header
            headerView
                .background(Color(NSColor.windowBackgroundColor))
            
            // Scrollable Tracks section
            ScrollView {
                if isLoading {
                    ProgressView()
                        .padding()
                        .frame(maxWidth: .infinity, minHeight: 300)
                } else if let loadedTracks = tracks, !loadedTracks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tracks")
                            .font(.headline)
                            .padding(.horizontal)
                            .padding(.top, 20)
                        
                        LazyVStack(spacing: 1) {
                            ForEach(Array(loadedTracks.enumerated()), id: \.element.id) { index, track in
                                TrackRowWithHover(
                                    track: track,
                                    index: index,
                                    playlist: playlist
                                )
                                
                                if index < loadedTracks.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(playlist.name)
        .task {
            await loadTracks()
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top, spacing: 20) {
                if let artwork = playlist.artwork {
                    ArtworkImage(artwork, width: 180)
                        .cornerRadius(12)
                        .shadow(radius: 8)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text(playlist.name)
                        .font(.system(size: 28, weight: .bold))
                    
                    Text("\(tracks?.count ?? 0) \((tracks?.count ?? 0) == 1 ? "track" : "tracks")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button(action: handleQueueButtonSelected) {
                        Label("Queue", systemImage: "play.fill")
                            .frame(width: 200)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 8)
                }
                
                Spacer()
            }
            .padding()
            
            Divider()
        }
    }
    
    private func loadTracks() async {
        defer { isLoading = false }
        do {
            let detailedPlaylist = try await playlist.with(.tracks)
            await MainActor.run {
                withAnimation {
                    self.tracks = detailedPlaylist.tracks
                }
            }
        } catch {
            print("Error loading tracks: \(error)")
        }
    }
                         
    private func handleQueueButtonSelected() {
        WebSocketClient.shared.queuePlaylist(playlist: playlist)
    }
}

// MARK: - Track Row with Hover Effect
struct TrackRowWithHover: View {
    let track: Track
    let index: Int
    let playlist: Playlist
    
    @State private var isHovering = false
    
    var body: some View {
        HStack {
            Text("\(index + 1)")
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .trailing)
                .font(.caption.monospacedDigit())
            
            PlaylistTrackCell(track, from: playlist)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .scaleEffect(isHovering ? 1.005 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .contentShape(Rectangle())
    }
}
