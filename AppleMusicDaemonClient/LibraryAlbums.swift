//
//  LibraryAlbums.swift
//  Improvements: Fixed typo, better search, toolbar
//

import SwiftUI
import MusicKit
import Combine

struct LibraryAlbums: View {
    @EnvironmentObject var viewModel: LibraryAlbumsModel
    @State private var searchQuery: String = ""

    var filteredAlbums: [Album] {
        if searchQuery.isEmpty {
            return viewModel.albums
        }
        return viewModel.albums.filter { album in
            album.title.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                loadingView()
                    .frame(maxHeight: 450)
            } else {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search Albums", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .modifier(ClearButton(text: $searchQuery))
                }
                .padding(8)
                #if os(iOS)
                .background(Color(.systemBackground))
                #elseif os(macOS)
                .background(Color(nsColor: .controlBackgroundColor))
                #endif
                .cornerRadius(8)
                .padding()
                
                // Results
                List(filteredAlbums) { album in
                    AlbumCell(album)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Albums")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Text("\(filteredAlbums.count) albums")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .onAppear() {
            if viewModel.albums.isEmpty {
                viewModel.fetchAlbums()
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

class LibraryAlbumsModel: ObservableObject {
    @Published var albums: [MusicKit.Album] = []
    @Published var isLoading: Bool = false

    @MainActor
    func fetchAlbums() {
        Task {
            do {
                isLoading = true
                let request = MusicLibraryRequest<Album>()
                let response = try await request.response()
                let albums = response.items
                self.albums = Array(albums)
                self.albums.sort { $0.title < $1.title }
                isLoading = false
            } catch {
                print("Error fetching playlists: \(error)")
            }
        }
    }
}
