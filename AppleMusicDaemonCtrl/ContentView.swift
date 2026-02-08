//
//  ContentView.swift
//  AppleMusicDaemonClient
//
//  Created by Richard Backhouse on 12/22/25.
//

import SwiftUI
import MusicKit
import Combine

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var bonjourService = BonjourService()
    @StateObject private var client = WebSocketClient.shared
    @StateObject private var viewModel = MusicViewModel()
    @StateObject private var albumsModel = LibraryAlbumsModel()
    @StateObject private var artistsModel = LibraryArtistsModel()
    @StateObject private var playlistsModel = LibraryPlaylistsModel()
    @StateObject private var stationsModel = LibraryStationsModel()
    @StateObject private var recentlyAddedModel = LibraryRecentlyAddedModel()
    @StateObject private var recentlyPlayedModel = LibraryRecentlyPlayedModel()
    @StateObject private var catalogViewModel = CatalogSearchModel()
    @Environment(\.scenePhase) private var scenePhase

    @State private var currentToast: ToastItem?
    @State var isShowingSheet = false
    @State var server = AMDConfig(
        name: "",
        host: "",
        port: 6600,
    )

    var body: some View {
        VStack(spacing: 0) {
            // Custom Toolbar
            CustomToolbar(isShowingSheet: $isShowingSheet)
                .environmentObject(client)
            
            ConnectionStatusBanner()
                .environmentObject(client)
            
            DetailView(
                albumsModel: albumsModel,
                artistsModel: artistsModel,
                playlistsModel: playlistsModel,
                stationsModel: stationsModel,
                catalogViewModel: catalogViewModel,
                recentlyAddedModel: recentlyAddedModel,
                recentlyPlayedModel: recentlyPlayedModel
            )
            .toast($currentToast)
        }
        .onAppear {
            setupApp()
            isShowingSheet = true
        }
        .onChange(of: client.toastItem ?? nil) { oldValue, newValue in
            if newValue != nil {
                currentToast = newValue
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                print("backgorund disconnecting from \(client.url)")
                client.disconnect()
            } else if newPhase == .active {
                if client.isConnected {
                    print("active disconnecting from \(client.url)")
                    client.disconnect()
                }
                print("active connecting to \(client.url)")
                client.connect(url: client.url)
            }
        }
        .sheet(isPresented: $isShowingSheet) {
        } content: {
            Connections(server: self.$server)
        }
    }
    
    // MARK: - Setup Methods
    private func setupApp() {
        viewModel.requestAuthorization()
        //viewModel.checkAuthAndSubscription()
        bonjourService.startStop()
    }
}

// MARK: - Custom Toolbar
struct CustomToolbar: View {
    @EnvironmentObject var client: WebSocketClient
    @Binding var isShowingSheet: Bool
    
    private var isPlaying: Bool {
        client.playbackStatus == .playing
    }
    
    var body: some View {
        ZStack {
            
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.8),
                    Color.purple.opacity(0.6),
                    Color.clear
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 60)
            
            HStack(spacing: 6) {
                // Left side - Connection button (to balance the layout)
                // Center - Playback Controls
                HStack(spacing: 6) {
                    // Mode Controls
                    Button(action: { client.shuffleMode() }) {
                        Image(systemName: client.isShuffleOn ? "shuffle" : "shuffle")
                            .font(.system(size: 20))
                            .foregroundColor(client.isShuffleOn ? .green : .primary)
                            .frame(width: 32, height: 32)
                    }
                    .help("Shuffle")
                    .buttonStyle(.plain)
                    
                    // Playback Controls
                    Button(action: { client.previous() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 20))
                            .frame(width: 32, height: 32)
                    }
                    .help("Previous")
                    .buttonStyle(.plain)
                    
                    Button(action: { client.stop() }) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 18))
                            .frame(width: 32, height: 32)
                    }
                    .help("Stop")
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        if isPlaying {
                            client.pause()
                        } else {
                            client.play()
                        }
                    }) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 22))
                            .frame(width: 36, height: 36)
                    }
                    .help(isPlaying ? "Pause" : "Play")
                    .keyboardShortcut(.space, modifiers: [])
                    .buttonStyle(.glass)
                    
                    Button(action: { client.next() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 20))
                            .frame(width: 32, height: 32)
                    }
                    .help("Next")
                    .buttonStyle(.plain)
                    
                    Button(action: { client.repeatMode() }) {
                        Image(systemName: repeatIcon)
                            .font(.system(size: 20))
                            .foregroundColor(client.isRepeatModeOn ? .green : .primary)
                            .frame(width: 32, height: 32)
                    }
                    .help("Repeat")
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                
                // Right side - Empty spacer (to balance the layout)
                Spacer()
                HStack(spacing: 6) {
                    Button(action: showConnectionsSheet) {
                        Image(systemName: "app.connected.to.app.below.fill")
                            .font(.system(size: 20))
                            .foregroundColor(client.isConnected ? .white : .primary)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                            )
                    }
                    .help("Connections")
                    .buttonStyle(.plain)
                }
                //.frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 5)
            //.background(Color(.systemBackground))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.gray.opacity(0.2)),
                alignment: .bottom
            )
        }
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    private var repeatIcon: String {
        switch client.isRepeatModeOn {
        case true:
            return "repeat"
        case false:
            return "repeat.1"
        }
    }
    
    private func showConnectionsSheet() {
        isShowingSheet = true
    }
}

// MARK: - Detail View
struct DetailView: View {
     @ObservedObject var albumsModel: LibraryAlbumsModel
     @ObservedObject var artistsModel: LibraryArtistsModel
     @ObservedObject var playlistsModel: LibraryPlaylistsModel
     @ObservedObject var stationsModel: LibraryStationsModel
     @ObservedObject var catalogViewModel: CatalogSearchModel
     @ObservedObject var recentlyAddedModel: LibraryRecentlyAddedModel
    @ObservedObject var recentlyPlayedModel: LibraryRecentlyPlayedModel

     var body: some View {
         TabView {
             Tab("Queue", systemImage: "music.quarternote.3") {
                 Queue()
             }
             Tab("Library", systemImage: "list.bullet") {
                 Library()
                     .environmentObject(albumsModel)
                     .environmentObject(artistsModel)
                     .environmentObject(playlistsModel)
                     .environmentObject(stationsModel)
                     .environmentObject(recentlyAddedModel)
                     .environmentObject(recentlyPlayedModel)
             }
             Tab("Search", systemImage: "magnifyingglass") {
                 CatalogSearch()
                     .environmentObject(catalogViewModel)
             }
         }
     }
 }

// MARK: - Message View
struct MessageView: View {
    var body: some View {
    }
}


// MARK: - Connection Status Banner
struct ConnectionStatusBanner: View {
    @EnvironmentObject var client: WebSocketClient
    
    var body: some View {
        if !client.isConnected {
            HStack {
                Image(systemName: "wifi.slash")
                Text("Disconnected from server")
                    .font(.callout)
                Spacer()
                ProgressView()
                    .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.15))
        }
    }
}

// MARK: - Connection Status Indicator
struct ConnectionStatusIndicator: View {
    @EnvironmentObject var client: WebSocketClient
    
    private var connectionStatusColor: Color {
        client.isConnected ? .green : .red
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(connectionStatusColor)
                .frame(width: 8, height: 8)
            Text(client.isConnected ? "Connected" : "Offline")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        #if os(iOS)
        .background(Color(.systemBackground))
        #elseif os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
        #endif
        .cornerRadius(6)
    }
}

// MARK: - Now Playing Toolbar Info
struct NowPlayingToolbarInfo: View {
    @EnvironmentObject var client: WebSocketClient
    @State private var showingPopover = false
    
    var body: some View {
        if let currentTrack = client.currentSong {
            Button(action: {
                showingPopover.toggle()
            }) {
                HStack(spacing: 8) {
                    if let artwork = currentTrack.artwork {
                        AsyncImage(url: artwork.url(width: 32, height: 32)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 32, height: 32)
                        .cornerRadius(4)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentTrack.title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        Text(currentTrack.artistName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: 200)
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingPopover) {
                NowPlayingPopover()
                    .environmentObject(client)
                    .frame(width: 400, height: 500)
            }
        }
    }
}

// MARK: - Now Playing Popover
struct NowPlayingPopover: View {
    @EnvironmentObject var client: WebSocketClient
    
    private var isPlaying: Bool {
        client.playbackStatus == .playing
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Large Artwork
            if let artwork = client.currentSong?.artwork {
                AsyncImage(url: artwork.url(width: 300, height: 300)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                        )
                }
                .frame(maxWidth: 300, maxHeight: 300)
                .cornerRadius(12)
                .shadow(radius: 10)
            }
            
            // Track Info
            VStack(spacing: 6) {
                Text(client.currentSong?.title ?? "Not Playing")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text(client.currentSong?.artistName ?? "")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text(client.currentSong?.albumTitle ?? "")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
            
            // Controls
            VStack(spacing: 20) {
                HStack(spacing: 30) {
                    Button(action: { client.previous() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 24))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { client.stop() }) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        if isPlaying {
                            client.pause()
                        } else {
                            client.play()
                        }
                    }) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 48))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { client.next() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 24))
                    }
                    .buttonStyle(.plain)
                }
                
                HStack(spacing: 40) {
                    Button(action: { client.shuffleMode() }) {
                        Image(systemName: client.isShuffleOn ? "shuffle.circle.fill" : "shuffle")
                            .font(.system(size: 20))
                            .foregroundColor(client.isShuffleOn ? .accentColor : .primary)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { client.repeatMode() }) {
                        Image(systemName: repeatIcon)
                            .font(.system(size: 20))
                            .foregroundColor(client.isRepeatModeOn ? .accentColor : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(24)
    }
    
    private var repeatIcon: String {
        switch client.isRepeatModeOn {
        case true:
            return "repeat.circle.fill"
        case false:
            return "repeat.1.circle.fill"
        }
    }
}

// MARK: - View Model
class MusicViewModel: ObservableObject {
    var canPlayAppleMusic: Bool = false
    init() {
    }
    
    func requestAuthorization() {
        Task {
            let status = await MusicAuthorization.request()
            switch status {
            case .authorized:
                print("Authorized")
            default:
                print("Not authorized")
            }
        }
    }
    
    func checkMusicSubscription() async {
        for await subscription in MusicSubscription.subscriptionUpdates{
            DispatchQueue.main.async{
                self.canPlayAppleMusic = subscription.canPlayCatalogContent
            }
        }
    }
    
    func checkAuthAndSubscription() async {
        let timeout = 2.0

        requestAuthorization()
        let subscriptionTask = Task {
            await checkMusicSubscription()
        }
        
        try? await withThrowingTaskGroup(of: Void.self){ group in
            group.addTask{
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if !subscriptionTask.isCancelled{
                    print("Timeout")
                    subscriptionTask.cancel()
                }
            }
            
            group.addTask{
                await subscriptionTask.value
            }
            
            try await group.next()
            group.cancelAll()
        }
    }
}
