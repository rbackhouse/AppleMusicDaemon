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
    let currentSong: Song?
    let songs: [Song]
    let playbackStatus: PlaybackStatus
    let playbackTime: Double
    let shuffleStatus: Bool
    let repeatStatus: Bool
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
}

@Observable
class AppleMusicObservable {
    @ObservationIgnored
    private var sockets: [WebSocket] = []
    
    func addWS(_ ws: WebSocket) {
        sockets.append(ws)
    }
    
    func removeWS(_ ws: WebSocket) {
        sockets.removeAll { $0 === ws }
    }
        
    func sendMessage(_ msg: MessageResponse) {
        let jsonEncoder = JSONEncoder()
        do {
            let jsonData = try jsonEncoder.encode(msg)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            
            for ws in sockets {
                ws.send(jsonString)
            }
        } catch {
            
        }
    }
    
    func startTimer() async throws {
        while true {
            let player = ApplicationMusicPlayer.shared
            //var currentId = "None"
            var currentSong: Song? = nil
            if let currentEntry = player.queue.currentEntry?.item {
                //currentId = currentEntry.id.rawValue
                switch currentEntry {
                case .song(let s):
                    currentSong = s
                case .musicVideo(_):
                    break
                @unknown default:
                    break
                }
            }
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

            //var ids: [String] = []
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
                    /*
                    let id = item.item?.id.rawValue ?? "None"
                    if id != "None" {
                        ids.append(id)
                    }
                    */
                }
            }
            let response = StatusResponse(currentSong: currentSong, songs: songs, playbackStatus: playbackStatus, playbackTime: playbackTime, shuffleStatus: shuffleStatus, repeatStatus: repeatStatus)
            //print(response)
            let jsonEncoder = JSONEncoder()
            let jsonData = try jsonEncoder.encode(response)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            
            for ws in sockets {
                try? await ws.send(jsonString)
            }
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
                let decoder = JSONDecoder()
                
                Task { @MainActor in
                    do {
                        let queueReq = try decoder.decode(QueueSong.self, from: jsonData)
                        print("Received: \(queueReq)")
                        let service = AppleMusicService()
                        let msg = try await service.queueSong(song: queueReq.song, append: queueReq.append)
                        sendMessage(msg)
                    } catch {}
                    do {
                        let queueReq = try decoder.decode(QueueAlbum.self, from: jsonData)
                        print("Received: \(queueReq)")
                        let service = AppleMusicService()
                        let msg = try await service.queueAlbum(album: queueReq.album, append: queueReq.append)
                        sendMessage(msg)
                    } catch {}
                    do {
                        let queueReq = try decoder.decode(QueuePlaylist.self, from: jsonData)
                        print("Received: \(queueReq)")
                        let service = AppleMusicService()
                        let msg = try await service.queuePlaylist(playlist: queueReq.playlist)
                        sendMessage(msg)
                    } catch {}
                    do {
                        let queueReq = try decoder.decode(QueueStation.self, from: jsonData)
                        print("Received: \(queueReq)")
                        let service = AppleMusicService()
                        let msg = try await service.queueStation(station: queueReq.station)
                        sendMessage(msg)
                    } catch {}
                    do {
                        let commandReq = try decoder.decode(CommandRequest.self, from: jsonData)
                        print("Received: \(commandReq)")
                        let service = AppleMusicService()
                        try await service.runCommand(request: commandReq)
                    } catch {}
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
