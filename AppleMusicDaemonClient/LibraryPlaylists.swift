//
//  LibraryPlaylists.swift
//  AppleMusicBridgeClient
//
//  Created by Richard Backhouse on 2/22/25.
//

import SwiftUI
import MusicKit
import Combine

struct LibraryPlaylists: View {
    @EnvironmentObject var viewModel: LibraryPlaylistsModel
    @State private var searchQuery: String = ""

    var filteredPlaylists: [Playlist] {
        if searchQuery.isEmpty {
            return viewModel.playlists
        }
        return viewModel.playlists.filter { playlist in
            playlist.name.localizedCaseInsensitiveContains(searchQuery)
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
                    TextField("Search Playlists", text: $searchQuery)
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
                List(filteredPlaylists) { playlist in
                    PlaylistCell(playlist)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Playlists")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Text("\(filteredPlaylists.count) playlists")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .onAppear() {
            if viewModel.playlists.isEmpty {
                viewModel.fetchPlaylists()
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

class LibraryPlaylistsModel: ObservableObject {
    @Published var playlists: [MusicKit.Playlist] = []
    @Published var isLoading: Bool = false

    @MainActor
    func fetchPlaylists() {
        Task {
            do {
                isLoading = true
                let request = MusicLibraryRequest<Playlist>()
                let response = try await request.response()
                let playlists = response.items
                self.playlists = Array(playlists)
                self.playlists.sort { $0.name < $1.name }
                isLoading = false
            } catch {
                print("Error fetching playlists: \(error)")
            }
        }
    }
}


#Preview {
    LibraryPlaylists()
}
