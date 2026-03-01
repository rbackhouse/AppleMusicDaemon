//
//  WebSocketClient.swift
//  AppleMusicDaemonClient
//
//  Created by Richard Backhouse on 12/22/25.
//

import Foundation
import Combine
import MusicKit
import SwiftData

@Model
public class AMDConfig : Identifiable, Equatable {
    public var id: UUID
    var name: String
    var host: String
    var port: Int
    
    init(name: String, host: String, port: Int) {
        id = UUID()
        self.host = host
        self.port = port
        self.name = name
    }
}

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

struct MessageResponse: Codable {
    let level: MessageLevel
    let title: String
    let message: String
}

class WebSocketClient : NSObject, ObservableObject, URLSessionWebSocketDelegate {
    @Published var queue: [MusicKit.Song] = []
    @Published var playbackStatus: PlaybackStatus = .stopped
    @Published var currentSong: MusicKit.Song?
    @Published var currentIndex: Int = 0
    @Published var playbackTime: Double = 0
    @Published var playbackDuration: Double = 0
    @Published var playbackTimeLabel: String = ""
    @Published var playbackDurationLabel: String = ""
    @Published var url: URL = URL(string: "ws://127.0.0.1:9992/amdsocket")!

    @Published var isConnected = false
    @Published var isShuffleOn = false
    @Published var isRepeatModeOn = false
    
    @Published var toastItem: ToastItem?

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession!
    static let shared = WebSocketClient()
    private var isUpdating = false

    func connect(url: URL) {
        self.url = url
        session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        isConnected = true
        listenForMessages()
    }

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: "Closing connection".data(using: .utf8))
        webSocketTask = nil
        isConnected = false
    }
    
    private func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWith protocol: String?) {
        print("WebSocket Connected!")
        sendPing()
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("Disconnected: \(closeCode)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.connect(url: self!.url)
        }
    }

    func sendPing() {
        webSocketTask?.sendPing { error in
            if let error = error {
                print("Ping failed: \(error)")
                self.disconnect() // Disconnected if ping fails
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                    self?.sendPing()
                }
            }
        }
    }
    
    func play() {
        self.runCommand(commandType: .play)
    }
    
    func stop() {
        self.runCommand(commandType: .stop)
    }

    func pause() {
        self.runCommand(commandType: .pause)
    }

    func next() {
        self.runCommand(commandType: .next)
    }

    func previous() {
        self.runCommand(commandType: .previous)
    }
    
    func shuffleMode() {
        self.runCommand(commandType: .shuffle)
    }
    
    func repeatMode() {
        self.runCommand(commandType: .repeatsong)
    }

    func queueSong(song: Song, append: Bool = false) {
        Task { @MainActor in
            let queueRequest = QueueSong(song: song, append: append)
            let encoder = JSONEncoder()
            do {
                let data = try encoder.encode(queueRequest)
                let jsonString = String(data: data, encoding: .utf8)!
                sendMessage(jsonString)
            } catch {
                print("Error encoding JSON: \(error)")
            }
        }
    }
    
    func queueAlbum(album: Album, append: Bool = false) {
        Task { @MainActor in
            let queueRequest = QueueAlbum(album: album, append: append)
            let encoder = JSONEncoder()
            do {
                let data = try encoder.encode(queueRequest)
                let jsonString = String(data: data, encoding: .utf8)!
                sendMessage(jsonString)
            } catch {
                print("Error encoding JSON: \(error)")
            }
        }
    }
    
    func queuePlaylist(playlist: Playlist) {
        Task { @MainActor in
            let queueRequest = QueuePlaylist(playlist: playlist)
            let encoder = JSONEncoder()
            do {
                let data = try encoder.encode(queueRequest)
                let jsonString = String(data: data, encoding: .utf8)!
                sendMessage(jsonString)
            } catch {
                print("Error encoding JSON: \(error)")
            }
        }
    }
    
    func queueStation(station: Station) {
        Task { @MainActor in
            let queueRequest = QueueStation(station: station)
            let encoder = JSONEncoder()
            do {
                let data = try encoder.encode(queueRequest)
                let jsonString = String(data: data, encoding: .utf8)!
                sendMessage(jsonString)
            } catch {
                print("Error encoding JSON: \(error)")
            }
        }
    }
    
    func runCommand(commandType: CommandType) {
        Task { @MainActor in
            let commandRequest = CommandRequest(commandType: commandType)
            let encoder = JSONEncoder()
            do {
                let data = try encoder.encode(commandRequest)
                let jsonString = String(data: data, encoding: .utf8)!
                sendMessage(jsonString)
            } catch {
                print("Error encoding JSON: \(error)")
            }
        }
    }

    func sendMessage(_ message: String) {
        let message = URLSessionWebSocketTask.Message.string(message)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("Send error: \(error.localizedDescription)")
            }
        }
    }
    
    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .failure(let error):
                print("Receive error: \(error.localizedDescription)")
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    /*
                    self.toastItem = ToastItem(
                        level: .error,
                        title: "Error",
                        message: error.localizedDescription
                    )
                    */
                    self.disconnect()
                }
            case .success(let message):
                switch message {
                case .string(let text):
                    DispatchQueue.main.async {
                        let jsonData = text.data(using: .utf8)!
                        let decoder = JSONDecoder()
                        do {
                            let status = try decoder.decode(StatusResponse.self, from: jsonData)
                            self!.expand(status: status)
                        } catch {
                        }
                        do {
                            let queuestate = try decoder.decode(QueueResponse.self, from: jsonData)
                            self!.queueChanged(queuestate: queuestate)
                        } catch {
                        }
                        do {
                            let msg = try decoder.decode(MessageResponse.self, from: jsonData)
                            print(msg)
                            let level: ToastLevel
                            switch msg.level {
                            case .success:
                                level = .success
                            case .error:
                                level = .error
                            case .warning:
                                level = .warning
                            case .info:
                                level = .info
                            }
                            self!.toastItem = ToastItem(
                                level: level,
                                title: msg.title,
                                message: msg.message
                            )
                       } catch {
                       }
                    }
                case .data(let data):
                    print("Received data: \(data.count) bytes")
                @unknown default:
                    fatalError()
                }
                self?.listenForMessages()
            }
        }
    }

    @MainActor
    func queueChanged(queuestate: QueueResponse) {
        Task {
            guard !isUpdating else { return }
            isUpdating = true

            print("Queue changed enter")
            if !checkSong(song1: self.currentSong, song2: queuestate.currentSong) {
                if queuestate.currentSong != nil {
                    self.currentSong = await getSong(queuestate.currentSong!)
                }
            }
            if checkQueue(queuestate: queuestate) {
                print("Resetting Queue")
                self.queue.removeAll()
                for song in queuestate.songs {
                    let s = await getSong(song)
                    if s != nil {
                        self.queue.append(s!)
                    }
                }
            }
            if queuestate.currentSong != nil {
                let x = queuestate.currentSong!
                for i in 0..<queue.count {
                    let y = queue[i]
                    if x.title == y.title && x.albumTitle == y.albumTitle && x.artistName == y.artistName {
                        currentIndex = i
                    }
                }
            }
            print("Queue changed exit")
            isUpdating = false
        }
    }
    
    @MainActor
    func expand(status: StatusResponse) {
        self.playbackStatus = status.playbackStatus
        self.playbackTime = status.playbackTime.rounded(.down)
        self.playbackDuration =  currentSong?.duration ?? 100
        self.playbackDuration.round(.down)
        let mins = (self.playbackTime / 60).rounded(.down)
        let secs = self.playbackTime - mins * 60
        let dmins = (self.playbackDuration / 60).rounded(.down)
        let dsecs = self.playbackDuration - dmins * 60
        self.playbackTimeLabel = String(format: "%02d:%02d", Int(mins), Int(secs))
        self.playbackDurationLabel = String(format: "%02d:%02d", Int(dmins), Int(dsecs))
        self.isRepeatModeOn = status.repeatStatus
        self.isShuffleOn = status.shuffleStatus
    }
    
    func checkSong(song1: Song?, song2: Song?) -> Bool {
        if song1 == nil {
            return false
        }
        if song2 == nil {
            return false
        }
        let x = song1!
        let y = song2!
        if x.title != y.title || x.albumTitle != y.albumTitle || x.artistName != y.artistName {
            return false
        }
        return true
    }
    
    func checkQueue(queuestate: QueueResponse) -> Bool {
        if queue.count != queuestate.songs.count {
            return true
        }
        for i in 0..<queue.count {
            if checkSong(song1: queue[i], song2: queuestate.songs[i]) == false {
                return true
            }
        }
        return false
    }
    
    func getSong(_ song: Song) async -> Song? {
        do {
            var req = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: song.id)
            req.limit = 1
            let resp = try await req.response()
            if resp.items.isEmpty == false {
                return resp.items.first
            }
        } catch {
            print("Failed to get song with title: \(song.title) artist: \(song.artistName) error: \(error)")
            do {
                let term = song.title + " by " + song.artistName
                var req = MusicCatalogSearchRequest(term: term, types: [Song.self])
                req.limit = 1
                let resp = try await req.response()
                if resp.songs.isEmpty == false {
                    return resp.songs.first
                }
            } catch {
                print("Failed to get song via search with title: \(song.title) artist: \(song.artistName) error: \(error)")
            }
        }
        return song
    }
}

