//
//  AppleMusicDaemon.swift
//  AppleMusicDaemon
//
//  Created by Richard Backhouse on 12/22/25.
//

import Vapor
import Observation
import Foundation
import MusicKit
import Combine

enum CommandType: String, Codable {
    case play
    case pause
    case stop
    case previous
    case next
    case shuffle
    case repeatsong
}

struct QueueSong: Codable {
    let song: Song
    let append: Bool;
}

struct QueueAlbum: Codable {
    let album: Album
    let append: Bool;
}

struct QueuePlaylist: Codable {
    let playlist: Playlist
}

struct QueueStation: Codable {
    let station: Station
}

struct CommandRequest: Codable {
    let commandType: CommandType
}

enum PlaybackStatus: String, Codable {
    case playing
    case paused
    case stopped
    case seekingforward
    case seekingbackward
}

struct StatusResponse: Codable {
    let playbackStatus: PlaybackStatus
    let playbackTime: Double
    let shuffleStatus: Bool
    let repeatStatus: Bool
}

struct QueueResponse: Codable {
    let currentSong: Song?
    let songs: [Song]
}

enum MessageLevel: String, Codable {
    case error
    case warning
    case success
    case info
}

public struct MessageResponse: Codable {
    let level: MessageLevel
    let title: String
    let message: String
}

/// Everything a client can send. Synthesized Codable wraps each case, e.g.
/// {"queueSong":{"_0":{"song":{...},"append":true}}} -- keep in sync with the client.
enum ClientMessage: Codable {
    case queueSong(QueueSong)
    case queueAlbum(QueueAlbum)
    case queuePlaylist(QueuePlaylist)
    case queueStation(QueueStation)
    case command(CommandRequest)
}

/// Everything the server can send. Keep in sync with the client.
enum ServerMessage: Codable {
    case status(StatusResponse)
    case queue(QueueResponse)
    case message(MessageResponse)
}

public struct AppleMusicService {
    func queueSong(
        song: Song,
        append: Bool
    ) async throws -> MessageResponse {
        var request = MusicLibraryRequest<Song>.init()
        request.filter(matching: \.id, equalTo: song.id)
        let response = try await request.response()
        if response.items.count > 0 {
            print("song found in library \(song.title)")
            let s = response.items[0]
            try await _queueSong(s, append: append)
            return MessageResponse(level: .success, title: "Song Queued", message: "\(song.title) queued to play from library append = \(append)")
        } else {
            print("song not found in library \(song.title) searching catalog")
            var catreq = MusicCatalogSearchRequest(term: song.title, types: [Song.self])
            catreq.limit = 25
            let catresp = try await catreq.response()
            if catresp.songs.count > 0 {
                print("\(catresp.songs.count) matching songs found in catalog for \(song.title)")
                let filteredSongs = catresp.songs.filter { s in
                    print("filtered \(s.title)) \(s.artistName) \(String(describing: s.albumTitle))")
                    return s.albumTitle == song.albumTitle && s.artistName == song.artistName
                }
                if !filteredSongs.isEmpty {
                    print("song found in catalog \(song.title)")
                    let s = filteredSongs[0]
                    try await _queueSong(s, append: append)
                    return MessageResponse(level: .success, title: "Song Queued", message: "\(song.title) queued to play from catalog append = \(append)")
                }
                else {
                    return MessageResponse(level: .error, title: "Song Queue Failed", message: "Song \(song.title) not found failed to be queued to play")
                }
            } else {
                print("song not found in catalog \(song.title)")
                return MessageResponse(level: .error, title: "Song Queue Failed", message: "Song \(song.title) not found failed to be queued to play")
            }
        }
    }
    
    func _queueSong(_ song: Song, append: Bool) async throws {
        let player = ApplicationMusicPlayer.shared
        if append {
            if player.queue.entries.isEmpty {
                player.queue = [song]
            } else {
                try await player.queue.insert(song, position: .tail)
            }
        } else {
            player.queue = [song]
        }
        try await player.prepareToPlay()
        print("song \(song.title) prepareToPlay")
    }
    
    func queueAlbum(
        album: Album,
        append: Bool
    ) async throws -> MessageResponse {
        var request = MusicLibraryRequest<Album>.init()
        request.filter(matching: \.id, equalTo: album.id)
        let response = try await request.response()
        if response.items.count > 0 {
            print("album found in library \(album.title)")
            let albums = response.items.prefix(1)
            try await _queueAlbum(albums[0], append: append)
            return MessageResponse(level: .success, title: "Album Queued", message: "\(album.title) queued to play from library append = \(append)")
        } else {
            print("album not found in library \(album.title) searching catalog")
            var catreq = MusicCatalogSearchRequest(term: album.title, types: [Album.self])
            catreq.limit = 25
            let catresp = try await catreq.response()
            if catresp.albums.count > 0 {
                print("\(catresp.albums.count) matching songs found in catalog for \(album.title)")
                let filteredAlbums = catresp.albums.filter { a in
                    print("filtered \(a.title)) \(a.artistName)")
                    return a.title == album.title && a.artistName == album.artistName
                }
                if !filteredAlbums.isEmpty {
                    print("album found in catalog \(album.title)")
                    let album = filteredAlbums[0]
                    try await _queueAlbum(album, append: append)
                    return MessageResponse(level: .success, title: "Album Queued", message: "\(album.title) queued to play from catalog append = \(append)")
                } else {
                    return MessageResponse(level: .error, title: "Album Queue Failed", message: "Album \(album.title) not found failed to be queued to play")
                }
            } else {
                return MessageResponse(level: .error, title: "Album Queue Failed", message: "Album \(album.title) not found failed to be queued to play")
            }
        }
    }
    
    func _queueAlbum(_ album: Album, append: Bool) async throws {
        let player = ApplicationMusicPlayer.shared
        if append {
            if player.queue.entries.isEmpty {
                player.queue = [album]
            } else {
                try await player.queue.insert(album, position: .tail)
            }
        } else {
            player.queue = [album]
        }
        print("album \(album.title) prepareToPlay")
        try await player.prepareToPlay()
    }

    func queuePlaylist(
        playlist: Playlist
    ) async throws -> MessageResponse {
        var request = MusicLibraryRequest<Playlist>.init()
        request.filter(matching: \.name, equalTo: playlist.name)
        let response = try await request.response()
        if response.items.count > 0 {
            let playlists = response.items.prefix(1)
            let player = ApplicationMusicPlayer.shared
            player.queue = [playlists[0]]
            try await player.prepareToPlay()
            return MessageResponse(level: .success, title: "Playlist Queued", message: "\(playlist.name) queued to play")
        } else {
            return MessageResponse(level: .error, title: "Playlist Queue Failed", message: "Playlist \(playlist.name) not found failed to be queued to play")
        }
    }
    
    func queueStation(
        station: Station
    ) async throws -> MessageResponse {
        let request = MusicCatalogResourceRequest<Station>(matching: \.id, equalTo: station.id)

        let response = try await request.response()
        if response.items.count > 0 {
            let stations = response.items.prefix(1)
            let player = ApplicationMusicPlayer.shared
            player.queue = [stations[0]]
            try await player.prepareToPlay()
            return MessageResponse(level: .success, title: "Station Queued", message: "\(station.name) queued to play")
        } else {
            return MessageResponse(level: .error, title: "Station Queue Failed", message: "Station \(station.name) not found failed to be queued to play")
        }
    }

    func runCommand(request: CommandRequest) async throws {
        let player = ApplicationMusicPlayer.shared

        switch request.commandType {
            case .play:
                try await player.play()
            case .pause:
                player.pause()
            case .next:
                try await player.skipToNextEntry()
            case .previous:
                try await player.skipToPreviousEntry()
            case .stop:
                player.stop()
                player.restartCurrentEntry()
            case .shuffle:
                if player.state.shuffleMode == .off {
                    player.state.shuffleMode = .songs
                } else {
                    player.state.shuffleMode = .off
                }
            case .repeatsong:
                if player.state.repeatMode == MusicPlayer.RepeatMode.none {
                    player.state.repeatMode = .all
                } else {
                    player.state.repeatMode = MusicPlayer.RepeatMode.none
                }
        }
    }

    enum RequestError: LocalizedError {
        case invalid

        var errorDescription: String? {
            switch self {
            case .invalid: return "Invalid request"
            }
        }
    }

    /// Decodes one client request and runs it. Anything thrown by a service call
    /// propagates to the caller. Returns nil for requests with no reply message
    /// (player commands).
    func handle(_ data: Data) async throws -> MessageResponse? {
        let msg: ClientMessage
        do {
            msg = try JSONDecoder().decode(ClientMessage.self, from: data)
        } catch {
            print("Failed to decode client message: \(error)")
            throw RequestError.invalid
        }
        print("Received: \(msg)")
        switch msg {
        case .queueSong(let req):
            return try await queueSong(song: req.song, append: req.append)
        case .queueAlbum(let req):
            return try await queueAlbum(album: req.album, append: req.append)
        case .queuePlaylist(let req):
            return try await queuePlaylist(playlist: req.playlist)
        case .queueStation(let req):
            return try await queueStation(station: req.station)
        case .command(let req):
            try await runCommand(request: req)
            return nil
        }
    }
}

/// Thread-safe set of connected sockets. add/remove arrive on NIO event loops while
/// broadcasts come from Swift concurrency tasks, so every access goes through the lock.
/// (A lock rather than an actor so addWS/removeWS stay synchronous and ordered.)
final class SocketHub: @unchecked Sendable {
    private let lock = NSLock()
    private var sockets: [ObjectIdentifier: WebSocket] = [:]

    func add(_ ws: WebSocket) {
        lock.withLock { sockets[ObjectIdentifier(ws)] = ws }
    }

    func remove(_ ws: WebSocket) {
        lock.withLock { sockets[ObjectIdentifier(ws)] = nil }
    }

    /// Sends to every live socket. Fire-and-forget, so one slow client can't stall the rest.
    func broadcast(_ text: String) {
        for ws in liveSockets() {
            ws.send(text)
        }
    }

    private func liveSockets() -> [WebSocket] {
        lock.withLock { () -> [WebSocket] in
            // Reap sockets whose onClose we never saw (e.g. a very fast disconnect).
            sockets = sockets.filter { !$0.value.isClosed }
            return Array(sockets.values)
        }
    }
}

@Observable
class AppleMusicObservable {
    @ObservationIgnored
    private let hub = SocketHub()
    private var queueObserver: AnyCancellable?

    init() {
        let player = ApplicationMusicPlayer.shared
        self.queueObserver = player.queue.objectWillChange
           .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
           .sink { [weak self] in
               Task {
                   await self?.queueDidChange()
               }
           }
    }
    
    private func queueDidChange() async {
        print("queueDidChange")
        let player = ApplicationMusicPlayer.shared
        var currentSong: Song? = nil
        if let currentEntry = player.queue.currentEntry?.item {
            switch currentEntry {
            case .song(let s):
                currentSong = s
            case .musicVideo(_):
                break
            @unknown default:
                break
            }
        }
        var songs: [Song] = []
        
        for item in player.queue.entries {
            if item.item != nil {
                switch item.item {
                case .song(let s):
                    songs.append(s)
                case .musicVideo(_):
                    break
                case .none:
                    break
                @unknown default:
                    break
                }
            }
        }
        do {
            let response = QueueResponse(currentSong: currentSong, songs: songs)
            let jsonEncoder = JSONEncoder()
            let jsonData = try jsonEncoder.encode(ServerMessage.queue(response))
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            
            hub.broadcast(jsonString)
        } catch {
            print("Failed to encode queue update: \(error)")
        }
    }
    
    func addWS(_ ws: WebSocket) {
        hub.add(ws)
        Task {
            await queueDidChange()
        }
    }
    
    func removeWS(_ ws: WebSocket) {
        hub.remove(ws)
    }
        
    func sendMessage(_ msg: MessageResponse) {
        let jsonEncoder = JSONEncoder()
        do {
            let jsonData = try jsonEncoder.encode(ServerMessage.message(msg))
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            
            hub.broadcast(jsonString)
        } catch {
            print("Failed to encode message: \(error)")
        }
    }
    
    func startTimer() async throws {
        while true {
            let player = ApplicationMusicPlayer.shared
            let playbackTime = player.playbackTime
            var playbackStatus: PlaybackStatus
            switch player.state.playbackStatus {
                case .playing:
                    playbackStatus = .playing
                case .stopped:
                    playbackStatus = .stopped
                case .paused:
                    playbackStatus = .paused
                case .seekingForward:
                    playbackStatus = .seekingforward
                case .seekingBackward:
                    playbackStatus = .seekingbackward
                default:
                    playbackStatus = .stopped
            }
            var repeatStatus: Bool = false
            switch player.state.repeatMode {
                case .some(.none):
                    repeatStatus = false
                case .some(_):
                    repeatStatus = true
                case nil:
                    repeatStatus = false
            }
            var shuffleStatus: Bool = false
            switch player.state.shuffleMode {
                case .off:
                    shuffleStatus = false
                case .songs:
                    shuffleStatus = true
                case .none:
                    shuffleStatus = false
                case .some(_):
                    shuffleStatus = true
            }

            let response = StatusResponse(playbackStatus: playbackStatus, playbackTime: playbackTime, shuffleStatus: shuffleStatus, repeatStatus: repeatStatus)
            //print(response)
            let jsonEncoder = JSONEncoder()
            let jsonData = try jsonEncoder.encode(ServerMessage.status(response))
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            
            hub.broadcast(jsonString)
            try await Task.sleep(for: Duration.seconds(1))
        }
    }
}

public struct AppleMusicDaemon: Sendable {
    public var addWS: (WebSocket)->Void
    public var removeWS: (WebSocket)->Void
    public var sendMessage: (MessageResponse)->Void

    private func configure(_ app: Application) async throws {
        app.http.server.configuration.hostname = "0.0.0.0"
        app.http.server.configuration.port = 9992
        try routes(app)
    }
    
    private func routes(_ app: Application) throws {
        app.webSocket("amdsocket") { req, ws in
            print("WebSocket connected: \(ws)")

            addWS(ws)
            
            ws.onText { ws, text async in
                let jsonData = Data(text.utf8)

                Task { @MainActor in
                    do {
                        if let msg = try await AppleMusicService().handle(jsonData) {
                            sendMessage(msg)
                        }
                    } catch {
                        print("Request failed: \(error)")
                        sendMessage(MessageResponse(
                            level: .error,
                            title: "Request Failed",
                            message: error.localizedDescription
                        ))
                    }
                }
            }
            
            ws.onClose.whenComplete { _ in
                removeWS(ws)
            }
        }
    }
    
    public func startAsync() async throws {
        let env = try Environment.detect()

        let app = try await Application.make(env)
        
        do {
            try await configure(app)
            
            try await app.execute()
            try await app.asyncShutdown()
        } catch {
            app.logger.report(error: error)
            try? await app.asyncShutdown()
            throw error
        }
    }
}
