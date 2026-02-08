//
//  ArtistDetailView.swift
//  AppleMusicBridgeClient
//
//  Created by Richard Backhouse on 3/1/25.
//

import SwiftUI
import MusicKit

struct ArtistDetailView: View {
    init(_ artist: Artist) {
        self.artist = artist
    }
    
    let artist: Artist
    @State private var albums: MusicItemCollection<Album>?
    @State private var isLoading = false
    @State private var loadError: Error?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header section with artist info
                //headerSection
                    //.padding(.bottom, 24)
                
                // Albums section
                if isLoading {
                    ProgressView("Loading albums...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if let error = loadError {
                    errorView(error)
                } else if let loadedAlbums = albums, !loadedAlbums.isEmpty {
                    albumsGrid(loadedAlbums)
                } else if albums != nil {
                    Text("No albums found")
                        .foregroundColor(.secondary)
                        .padding(.top, 40)
                }
            }
            .padding()
        }
        //.frame(minWidth: 600, minHeight: 400)
        .navigationTitle(artist.name)
        .task {
            print("loading albums")
            await loadAlbums()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            if let artwork = artist.artwork {
                ArtworkImage(artwork, width: 200)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
            }
            
            Text(artist.name)
                .font(.system(size: 32, weight: .bold))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
    
    private func albumsGrid(_ loadedAlbums: MusicItemCollection<Album>) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Albums")
                .font(.title2.bold())
                .padding(.horizontal, 4)
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)
            ], spacing: 20) {
                ForEach(loadedAlbums) { album in
                    NavigationLink(destination: AlbumDetailView(album)) {
                        AlbumGridItem(album: album, artistName: artist.name)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Failed to load albums")
                .font(.headline)
            
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                Task {
                    await loadAlbums()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.top, 40)
    }
    
    private func loadAlbums() async {
        isLoading = true
        loadError = nil
        
        do {
            let detailedArtist = try await artist.with(.albums)
            update(albums: detailedArtist.albums)
        } catch {
            await MainActor.run {
                loadError = error
            }
        }
        
        isLoading = false
    }
    
    @MainActor
    private func update(albums: MusicItemCollection<Album>?) {
        withAnimation(.easeInOut(duration: 0.3)) {
            self.albums = albums
        }
    }
}

// MARK: - Supporting Views

struct AlbumGridItem: View {
    let album: Album
    let artistName: String
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let artwork = album.artwork {
                ArtworkImage(artwork, width: 160)
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(isHovered ? 0.3 : 0.1),
                           radius: isHovered ? 12 : 6,
                           x: 0,
                           y: isHovered ? 6 : 3)
                    .scaleEffect(isHovered ? 1.02 : 1.0)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(album.title)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                if let releaseDate = album.releaseDate {
                    Text(releaseDate.formatted(.dateTime.year()))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(width: 160)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}
