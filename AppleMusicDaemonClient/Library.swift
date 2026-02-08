import SwiftUI

struct ClearButton: ViewModifier {
    @Binding var text: String
    
    public func body(content: Content) -> some View {
        HStack {
            content
            if !text.isEmpty {
                Button(action: {
                    self.text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }
        }
    }
}

struct Library: View {
    @EnvironmentObject var albumsModel: LibraryAlbumsModel
    @EnvironmentObject var artistsModel: LibraryArtistsModel
    @EnvironmentObject var playlistsModel: LibraryPlaylistsModel
    @EnvironmentObject var stationsModel: LibraryStationsModel
    @EnvironmentObject var recentlyAddedModel: LibraryRecentlyAddedModel
    @EnvironmentObject var recentlyPlayedModel: LibraryRecentlyPlayedModel
    #if os(iOS)
    @State private var selection: LibrarySection? = .none
    #elseif os(macOS)
    @State private var selection: LibrarySection? = .artists
    #endif

    enum LibrarySection: String, CaseIterable {
        case artists = "Artists"
        case albums = "Albums"
        case playlists = "Playlists"
        case stations = "Stations"
        case recentlyAdded = "Recently Added"
        case recentlyPlayed = "Recently Played"

        var icon: String {
            switch self {
            case .artists: return "person.2"
            case .albums: return "square.stack"
            case .playlists: return "music.note.list"
            case .stations: return "dot.radiowaves.left.and.right"
            case .recentlyAdded: return "clock"
            case .recentlyPlayed: return "clock.badge"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(LibrarySection.allCases, id: \.self, selection: $selection) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .font(.title3)
                    .padding(.vertical, 4)
            }
            .navigationTitle("Library")
            .frame(minWidth: 200)
        } detail: {
            Group {
                switch selection {
                case .artists:
                    LibraryArtists().environmentObject(artistsModel)
                case .albums:
                    LibraryAlbums().environmentObject(albumsModel)
                case .playlists:
                    LibraryPlaylists().environmentObject(playlistsModel)
                case .stations:
                    LibraryStations().environmentObject(stationsModel)
                case .recentlyAdded:
                    LibraryRecentlyAdded().environmentObject(recentlyAddedModel)
                case .recentlyPlayed:
                    LibraryRecentlyPlayed().environmentObject(recentlyPlayedModel)
                case .none:
                    Text("Select a section")
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
