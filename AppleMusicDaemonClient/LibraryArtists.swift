//
//  LibraryArtists.swift
//  AppleMusicBridgeClient
//
//  Created by Richard Backhouse on 2/22/25.
//

import SwiftUI
import MusicKit
import Combine

struct LibraryArtists: View {
    @EnvironmentObject var viewModel: LibraryArtistsModel
    @State private var searchQuery: String = ""

    var filteredArtists: [Artist] {
        if searchQuery.isEmpty {
            return viewModel.artists
        }
        return viewModel.artists.filter { artist in
            artist.name.localizedCaseInsensitiveContains(searchQuery)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    loadingView()
                        .frame(maxHeight: 450)
                } else {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search Artists", text: $searchQuery)
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
                    List(filteredArtists) { artist in
                        ArtistCell(artist)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Artists")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Text("\(filteredArtists.count) artists")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .onAppear() {
                if viewModel.artists.isEmpty {
                    viewModel.fetchArtists()
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

class LibraryArtistsModel: ObservableObject {
    @Published var artists: [MusicKit.Artist] = []
    @Published var isLoading: Bool = false

    @MainActor
    func fetchArtists() {
        Task {
            do {
                isLoading = true
                let request = MusicLibraryRequest<Artist>()
                let response = try await request.response()
                let artists = response.items
                self.artists = Array(artists)
                self.artists.sort { $0.name < $1.name }
                isLoading = false
            } catch {
                print("Error fetching artists: \(error)")
            }
        }
    }
}

#Preview {
    LibraryArtists()
}
