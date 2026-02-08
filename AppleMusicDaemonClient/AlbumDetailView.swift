//
//  AlbumDetailView.swift
//  AppleMusicBridgeClient
//
//  Created by Richard Backhouse on 2/23/25.
//

import SwiftUI
import MusicKit

struct AlbumDetailView: View {
    init(_ album: Album) {
        self.album = album
    }
    
    let album: Album
    
    @State private var tracks: MusicItemCollection<Track>?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hoveredTrackId: Track.ID?
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            // Fixed header section with album art and info
            header
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 24)
                .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // Scrollable tracks section
            ScrollView {
                if isLoading {
                    ProgressView()
                        .padding(.top, 40)
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text(error)
                            .foregroundColor(.secondary)
                        Button("Retry") {
                            Task {
                                await loadTracks()
                            }
                        }
                    }
                    .padding(.top, 40)
                } else if let loadedTracks = tracks, !loadedTracks.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Tracks")
                            .font(.headline)
                            .padding(.horizontal)
                            .padding(.top, 20)
                            .padding(.bottom, 12)
                        
                        LazyVStack(spacing: 0) {
                            ForEach(Array(loadedTracks.enumerated()), id: \.element.id) { index, track in
                                HStack {
                                    Text("\(index + 1)")
                                        .foregroundColor(.secondary)
                                        .frame(width: 30, alignment: .trailing)
                                        .font(.caption.monospacedDigit())
                                    TrackCell(track, from: album)
                                    Spacer(minLength: 8)
                                    if isHovering {
                                        Image(systemName: "ellipsis")
                                            .foregroundColor(.secondary)
                                            .font(.system(size: 14))
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(hoveredTrackId == track.id ? Color.accentColor.opacity(0.1) : Color.clear)
                                )
                                .animation(.easeInOut(duration: 0.15), value: hoveredTrackId)
                                .onHover { isHovering in
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        hoveredTrackId = isHovering ? track.id : nil
                                        self.isHovering = isHovering
                                    }
                                }

                                if index < loadedTracks.count - 1 {
                                    Divider()
                                        .padding(.leading, 46)
                                }
                            }
                        }
                    }
                } else {
                    Text("No tracks available")
                        .foregroundColor(.secondary)
                        .padding(.top, 40)
                }
            }
        }
        .navigationTitle(album.title)
        .navigationSubtitle(album.artistName)
        .frame(minWidth: 600, minHeight: 400)
        .task {
            print("loading tracks")
            await loadTracks()
        }
    }
    
    private var header: some View {
        HStack(spacing: 24) {
            // Album artwork
            if let artwork = album.artwork {
                ArtworkImage(artwork, width: 200)
                    .cornerRadius(8)
                    .shadow(radius: 8)
            }
            
            // Album info and controls
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(album.title)
                        .font(.title.bold())
                    
                    Text(album.artistName)
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    if let releaseDate = album.releaseDate {
                        Text(releaseDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let trackCount = tracks?.count {
                        Text("\(trackCount) track\(trackCount == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 12) {
                    Button(action: handleQueueButtonSelected) {
                        Label("Queue", systemImage: "list.dash")
                            .frame(minWidth: 120)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button(action: handleAppendButtonSelected) {
                        Label("Append", systemImage: "text.append")
                            .frame(minWidth: 120)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 200)
    }
    
    private func loadTracks() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let detailedAlbum = try await album.with(.tracks)
            update(tracks: detailedAlbum.tracks)
        } catch {
            setError("Failed to load tracks: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    @MainActor
    private func update(tracks: MusicItemCollection<Track>?) {
        withAnimation(.easeInOut(duration: 0.2)) {
            self.tracks = tracks
        }
    }
    
    @MainActor
    private func setError(_ message: String) {
        errorMessage = message
    }
    
    private func handleQueueButtonSelected() {
        WebSocketClient.shared.queueAlbum(album: album)
    }
    
    private func handleAppendButtonSelected() {
        WebSocketClient.shared.queueAlbum(album: album, append: true)
    }
}
