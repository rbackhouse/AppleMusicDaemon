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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(spacing: 0) {
            // Fixed header section with album art and info
            header
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 20)
                .padding(.bottom, 24)
                .background(Color(.systemBackground))
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
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Retry") {
                            Task {
                                await loadTracks()
                            }
                        }
                    }
                    .padding(.top, 40)
                } else if let loadedTracks = tracks, !loadedTracks.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(loadedTracks.enumerated()), id: \.element.id) { index, track in
                                HStack(spacing: 8) {
                                    Text("\(index + 1)")
                                        .foregroundColor(.secondary)
                                        .frame(width: 30, alignment: .trailing)
                                        .font(.caption.monospacedDigit())
                                    TrackCell(track, from: album)
                                    Spacer(minLength: 4)
                                    if isHovering {
                                        Image(systemName: "ellipsis")
                                            .foregroundColor(.secondary)
                                            .font(.system(size: 14))
                                    }
                                }
                                .padding(.horizontal, horizontalPadding)
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
                                        .padding(.leading, 46 + horizontalPadding)
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
        .navigationBarTitleDisplayMode(.inline)
        //.navigationTitle(album.title)
        //.navigationSubtitle(album.artistName)
        .task {
            print("loading tracks")
            await loadTracks()
        }
    }
    
    private var horizontalPadding: CGFloat {
        horizontalSizeClass == .compact ? 16 : 24
    }
    
    private var artworkSize: CGFloat {
        horizontalSizeClass == .compact ? 140 : 200
    }
    
    private var header: some View {
        Group {
            if horizontalSizeClass == .compact {
                // Vertical layout for iPhone
                VStack(spacing: 16) {
                    if let artwork = album.artwork {
                        ArtworkImage(artwork, width: artworkSize)
                            .cornerRadius(8)
                            .shadow(radius: 8)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            
                            Text(album.title)
                                .font(.title2.bold())
                                .lineLimit(2)
                            
                            HStack(spacing: 8) {
                                Text(album.artistName)
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                
                                if let releaseDate = album.releaseDate {
                                    Text(releaseDate.formatted(date: .abbreviated, time: .omitted))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let trackCount = tracks?.count {
                                    Text("•")
                                        .foregroundColor(.secondary)
                                    Text("\(trackCount) track\(trackCount == 1 ? "" : "s")")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        // Action buttons - full width on iPhone
                        VStack(spacing: 8) {
                            HStack(spacing: 16) {
                                Button(action: handleQueueButtonSelected) {
                                    Label("Queue", systemImage: "list.dash")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                
                                Button(action: handleAppendButtonSelected) {
                                    Label("Append", systemImage: "text.append")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                // Horizontal layout for iPad
                HStack(spacing: 24) {
                    if let artwork = album.artwork {
                        ArtworkImage(artwork, width: artworkSize)
                            .cornerRadius(8)
                            .shadow(radius: 8)
                    }
                    
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
        }
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
