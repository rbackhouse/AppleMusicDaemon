//
//  LibraryRecentlyPlayed.swift
//  AppleMusicDaemonClient
//
//  Created by Richard Backhouse on 1/17/26.
//

import SwiftUI
import MusicKit
import Combine

struct LibraryRecentlyPlayed: View {
    @EnvironmentObject var viewModel: LibraryRecentlyPlayedModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    loadingView()
                        .frame(maxHeight: 450)
                } else {
                    List {
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
                        
                        if !viewModel.playlists.isEmpty {
                            Section("Playlists") {
                                ForEach(viewModel.playlists) { playlist in
                                    PlaylistCell(playlist)
                                }
                            }
                        }

                        if !viewModel.stations.isEmpty {
                            Section("Stations") {
                                ForEach(viewModel.stations) { station in
                                    StationCell(station)
                                }
                            }
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .navigationTitle("Recently Played")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear() {
                if viewModel.albums.isEmpty {
                    viewModel.fetchRecentlyPlayed()
                }
            }
        }
    }
}

@ViewBuilder
private func loadingView() -> some View {
    ProgressView()
        .scaleEffect(2)
        .tint(.blue)
}

class LibraryRecentlyPlayedModel: ObservableObject {
    @Published var albums: [MusicKit.Album] = []
    @Published var playlists: [MusicKit.Playlist] = []
    @Published var stations: [MusicKit.Station] = []
    @Published var songs: [MusicKit.Song] = []
    @Published var isLoading: Bool = false

    @MainActor
    func fetchRecentlyPlayed() {
        Task {
            do {
                isLoading = true
                var request = MusicRecentlyPlayedRequest<RecentlyPlayedMusicItem>()
                request.limit = 10
                let response = try await request.response()
                for item in response.items {
                    switch item {
                    case .album(let a):
                        albums.append(a)
                    case .playlist(let p):
                        playlists.append(p)
                    case .station(let s):
                        stations.append(s)
                    @unknown default:
                        break
                    }
                }
                var songsreq = MusicRecentlyPlayedRequest<Song>()
                songsreq.limit = 25
                let songsresp = try await songsreq.response()
                for song in songsresp.items {
                    songs.append(song)
                }
                isLoading = false
            } catch {
                print("Error fetching recently played: \(error)")
            }
        }
    }
}
