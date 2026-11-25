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

/// One queue slot. `id` is unique per entry, so the same song queued twice stays distinguishable.
struct QueueEntry: Codable {
    let id: String
    let song: Song
}

struct QueueResponse: Codable {
    let currentEntryID: String?
    let entries: [QueueEntry]
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
    case setShuffle(Bool)
    case setRepeat(Bool)
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
            // The song usually came from the catalog, so its id works directly.
            let byID = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: song.id)
            if let found = try? await byID.response().items.first {
                try await _queueSong(found, append: append)
                return MessageResponse(level: .success, title: "Song Queued", message: "\(song.title) queued to play from catalog append = \(append)")
            }
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
            try await _queueAlbum(response.items[0], append: append)
            return MessageResponse(level: .success, title: "Album Queued", message: "\(album.title) queued to play from library append = \(append)")
        } else {
            print("album not found in library \(album.title) searching catalog")
            var catreq = MusicCatalogSearchRequest(term: album.title, types: [Album.self])
            catreq.limit = 25
            let catresp = try await catreq.response()
            if catresp.albums.count > 0 {
                print("\(catresp.albums.count) matching albums found in catalog for \(album.title)")
                let filteredAlbums = catresp.albums.filter { a in
                    print("filtered \(a.title)) \(a.artistName)")
                    return a.title == album.title && a.artistName == album.artistName
                }
                if !filteredAlbums.isEmpty {
                    print("album found in catalog \(album.title)")
                    let matched = filteredAlbums[0]
                    try await _queueAlbum(matched, append: append)
                    return MessageResponse(level: .success, title: "Album Queued", message: "\(matched.title) queued to play from catalog append = \(append)")
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
        var byID = MusicLibraryRequest<Playlist>()
        byID.filter(matching: \.id, equalTo: playlist.id)
        var response = try await byID.response()
        if response.items.isEmpty {
            // The id may be a catalog id that doesn't exist in the library; fall back to the name.
            var byName = MusicLibraryRequest<Playlist>()
            byName.filter(matching: \.name, equalTo: playlist.name)
            response = try await byName.response()
        }
        if response.items.count > 0 {
            let player = ApplicationMusicPlayer.shared
            player.queue = [response.items[0]]
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
            let player = ApplicationMusicPlayer.shared
            player.queue = [response.items[0]]
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
        }
    }

    /// Explicit rather than toggling, so a client with stale UI state can't flip the wrong way.
    func setShuffle(_ on: Bool) {
        ApplicationMusicPlayer.shared.state.shuffleMode = on ? .songs : .off
    }

    func setRepeat(_ on: Bool) {
        ApplicationMusicPlayer.shared.state.repeatMode = on ? .all : MusicPlayer.RepeatMode.none
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
        case .setShuffle(let on):
            setShuffle(on)
            return nil
        case .setRepeat(let on):
            setRepeat(on)
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

    var isEmpty: Bool {
        lock.withLock { sockets.isEmpty }
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
    private var stateObserver: AnyCancellable?

    init() {
        let player = ApplicationMusicPlayer.shared
        self.queueObserver = player.queue.objectWillChange
           .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
           .sink { [weak self] in
               Task {
                   await self?.queueDidChange()
                   self?.broadcastStatus()
               }
           }
        self.stateObserver = player.state.objectWillChange
           .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
           .sink { [weak self] in
               self?.broadcastStatus()
           }
    }
    
    private func queueDidChange(to target: WebSocket? = nil) async {
        print("queueDidChange")
        let player = ApplicationMusicPlayer.shared
        let entries: [QueueEntry] = player.queue.entries.compactMap { entry in
            guard case .song(let song)? = entry.item else { return nil }   // music videos are skipped
            return QueueEntry(id: entry.id, song: song)
        }
        // Only name a current entry the client can actually find in the list we send.
        let currentID = player.queue.currentEntry?.id
        let currentEntryID = entries.contains { $0.id == currentID } ? currentID : nil
        do {
            let response = QueueResponse(currentEntryID: currentEntryID, entries: entries)
            let jsonEncoder = JSONEncoder()
            let jsonData = try jsonEncoder.encode(ServerMessage.queue(response))
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            
            if let target {
                try? await target.send(jsonString)
            } else {
                hub.broadcast(jsonString)
            }
        } catch {
            print("Failed to encode queue update: \(error)")
        }
    }
    
    func addWS(_ ws: WebSocket) {
        hub.add(ws)
        Task {
            await queueDidChange(to: ws)
            broadcastStatus(to: ws)
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
    
    private func currentStatus() -> StatusResponse {
        let player = ApplicationMusicPlayer.shared
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
        return StatusResponse(playbackStatus: playbackStatus, playbackTime: player.playbackTime, shuffleStatus: shuffleStatus, repeatStatus: repeatStatus)
    }

    private func broadcastStatus(to target: WebSocket? = nil) {
        guard let text = encodeServerMessage(.status(currentStatus())) else { return }
        if let target {
            target.send(text)
        } else {
            hub.broadcast(text)
        }
    }

    /// Status is pushed whenever player state or the queue changes. This slow tick only
    /// resyncs the playback position (clients advance it locally in between), and it does
    /// no work while nobody is connected.
    func startTimer() async throws {
        while true {
            if !hub.isEmpty {
                broadcastStatus()
            }
            try await Task.sleep(for: Duration.seconds(5))
        }
    }
}

/// Encodes one server message as the JSON text frame clients expect.
private func encodeServerMessage(_ message: ServerMessage) -> String? {
    guard let data = try? JSONEncoder().encode(message) else { return nil }
    return String(data: data, encoding: .utf8)
}

/// Constant-time comparison, so response timing doesn't leak how much of a token matched.
private func constantTimeEquals(_ a: String, _ b: String) -> Bool {
    let x = Array(a.utf8), y = Array(b.utf8)
    guard x.count == y.count else { return false }
    var diff: UInt8 = 0
    for i in 0..<x.count { diff |= x[i] ^ y[i] }
    return diff == 0
}

/// Rejects requests that don't carry the shared secret as `Authorization: Bearer <token>`.
/// Runs before the WebSocket upgrade, so a bad token gets a plain HTTP 401 the client can recognize.
struct TokenAuthMiddleware: AsyncMiddleware {
    let token: String

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let supplied = request.headers.bearerAuthorization?.token ?? ""
        guard constantTimeEquals(supplied, token) else {
            print("Rejected connection from \(request.remoteAddress?.description ?? "unknown"): missing or invalid token")
            throw Abort(.unauthorized)
        }
        return try await next.respond(to: request)
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
    
    /// Shared secret clients must send as `Authorization: Bearer <token>`.
    /// Opt-in: unset or empty leaves the server open, as before.
    private static func authToken() -> String? {
        let token = Environment.get("AMD_TOKEN") ?? UserDefaults.standard.string(forKey: "AMDAuthToken")
        guard let token, !token.isEmpty else { return nil }
        return token
    }

    private func routes(_ app: Application) throws {
        let root: RoutesBuilder
        if let token = Self.authToken() {
            root = app.grouped(TokenAuthMiddleware(token: token))
        } else {
            print("WARNING: no auth token configured (set AMD_TOKEN or the AMDAuthToken default); any client on the network can connect and control playback")
            root = app
        }

        root.webSocket("amdsocket") { req, ws in
            print("WebSocket connected: \(ws)")

            ws.pingInterval = .seconds(15)
            addWS(ws)
            
            ws.onText { ws, text async in
                let jsonData = Data(text.utf8)

                Task { @MainActor in
                    let reply: MessageResponse?
                    do {
                        reply = try await AppleMusicService().handle(jsonData)
                    } catch {
                        print("Request failed: \(error)")
                        reply = MessageResponse(
                            level: .error,
                            title: "Request Failed",
                            message: error.localizedDescription
                        )
                    }
                    // Toasts go to whoever asked; queue and status changes are still broadcast.
                    if let reply, let text = encodeServerMessage(.message(reply)) {
                        try? await ws.send(text)
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
