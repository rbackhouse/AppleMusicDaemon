//
//  LibraryRecentlyAdded.swift
//  AppleMusicDaemonClient
//
//  Created by Richard Backhouse on 12/29/25.
//

import SwiftUI
import MusicKit
import Combine

struct LibraryRecentlyAdded: View {
    @EnvironmentObject var viewModel: LibraryRecentlyAddedModel

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
                    }
                    .listStyle(.inset)
                }
            }
            .navigationTitle("Recently Added")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear() {
                if viewModel.albums.isEmpty {
                    viewModel.fetchRecentlyAdded()
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

class LibraryRecentlyAddedModel: ObservableObject {
    @Published var albums: [MusicKit.Album] = []
    @Published var isLoading: Bool = false

    @MainActor
    func fetchRecentlyAdded() {
        Task {
            do {
                isLoading = true
                var request = MusicLibraryRequest<Album>()
                request.sort(by: \.libraryAddedDate, ascending: false)
                request.limit = 25
                let response = try await request.response()
                let albums = response.items
                self.albums = Array(albums)
                isLoading = false
            } catch {
                print("Error fetching playlists: \(error)")
            }
        }
    }
}
