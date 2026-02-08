//
//  CatalogSearch.swift
//  AppleMusicBridgeClient
//
//  Created by Richard Backhouse on 2/22/25.
//

import SwiftUI
import MusicKit
import Combine

struct CatalogSearch: View {
    @State private var searchText = ""
    @EnvironmentObject var viewModel: CatalogSearchModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isSearching {
                    ProgressView("Searching...")
                        .padding()
                } else if !searchText.isEmpty && viewModel.isEmpty {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different search term")
                    )
                } else {
                    List {
                        if !viewModel.artists.isEmpty {
                            Section("Artists") {
                                ForEach(viewModel.artists) { artist in
                                    NavigationLink(destination: ArtistDetailView(artist)) {
                                        ArtistRow(artist: artist)
                                    }
                                }
                            }
                        }
                        
                        if !viewModel.albums.isEmpty {
                            Section("Albums") {
                                ForEach(viewModel.albums) { album in
                                    NavigationLink(destination: AlbumDetailView(album)) {
                                        AlbumRow(album: album)
                                    }
                                }
                            }
                        }
                        
                        if !viewModel.songs.isEmpty {
                            Section("Songs") {
                                ForEach(viewModel.songs) { song in
                                    VStack {
                                        SongRow(song: song)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .searchable(text: $searchText, prompt: "Search Catalog")
            .onSubmit(of: .search) {
                guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                viewModel.searchCatalog(term: searchText)
            }
            .onChange(of: searchText) { oldValue, newValue in
                if newValue.isEmpty {
                    viewModel.clearResults()
                }
            }
            .navigationTitle("Catalog Search")
        }
    }
}

// MARK: - Row Components

struct ArtistRow: View {
    let artist: MusicKit.Artist
    
    var body: some View {
        HStack(spacing: 12) {
            if let artwork = artist.artwork {
                ArtworkImage(artwork, width: 60)
                    .frame(width: 60, height: 60)
                    .cornerRadius(30)
            } else {
                Circle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.secondary)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(artist.name)
                    .font(.headline)
                    .lineLimit(1)
                Text("Artist")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AlbumRow: View {
    let album: MusicKit.Album
    
    var body: some View {
        HStack(spacing: 12) {
            if let artwork = album.artwork {
                ArtworkImage(artwork, width: 60)
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.secondary)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(album.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(album.artistName)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text("Album")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SongRow: View {
    let song: MusicKit.Song
    @State private var isPressed = false
    @State private var showQueuedFeedback = false

    var body: some View {
        HStack(spacing: 12) {
            if let artwork = song.artwork {
                ArtworkImage(artwork, width: 60)
                    .frame(width: 60, height: 60)
                    .cornerRadius(6)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.secondary)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(song.artistName)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text("Song")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .opacity(showQueuedFeedback ? 0.5 : 1.0)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                WebSocketClient.shared.queueSong(song: song, append: true)
            } label: {
                Label("Append to Queue", systemImage: "play.fill")
            }
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
            
            withAnimation(.easeOut(duration: 0.2).delay(0.1)) {
                showQueuedFeedback = true
            }
            
            WebSocketClient.shared.queueSong(song: song)
            withAnimation(.easeIn(duration: 0.2).delay(0.3)) {
                showQueuedFeedback = false
                isPressed = false
            }
        }
    }
}

// MARK: - View Model

class CatalogSearchModel: ObservableObject {
    @Published var songs: [MusicKit.Song] = []
    @Published var artists: [MusicKit.Artist] = []
    @Published var albums: [MusicKit.Album] = []
    @Published var isSearching = false
    
    var isEmpty: Bool {
        songs.isEmpty && artists.isEmpty && albums.isEmpty
    }

    @MainActor
    func searchCatalog(term: String) {
        guard !term.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        isSearching = true
        
        Task {
            do {
                print("Searching catalog: \(term)")
                var request = MusicCatalogSearchRequest(
                    term: term,
                    types: [Album.self, Song.self, Artist.self]
                )
                request.limit = 25
                let response = try await request.response()
                print("Searched catalog: \(term)")

                self.artists = Array(response.artists)
                self.albums = Array(response.albums)
                self.songs = Array(response.songs)
            } catch {
                print("Error searching catalog: \(error)")
                // Could add error state here for user feedback
            }
            
            isSearching = false
        }
    }
    
    func clearResults() {
        songs = []
        artists = []
        albums = []
    }
}

#Preview {
    CatalogSearch()
        .environmentObject(CatalogSearchModel())
}
