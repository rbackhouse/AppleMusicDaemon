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

/// Everything the client can send. Synthesized Codable wraps each case, e.g.
/// {"queueSong":{"_0":{"song":{...},"append":true}}} -- keep in sync with the server.
enum ClientMessage: Codable {
    case queueSong(QueueSong)
    case queueAlbum(QueueAlbum)
    case queuePlaylist(QueuePlaylist)
    case queueStation(QueueStation)
    case command(CommandRequest)
}

/// Everything the server can send. Keep in sync with the server.
enum ServerMessage: Codable {
    case status(StatusResponse)
    case queue(QueueResponse)
    case message(MessageResponse)
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
    private var queueTask: Task<Void, Never>?
    private var shouldReconnect = false

    func connect(url: URL) {
        shouldReconnect = true
        self.url = url
        if session == nil {
            session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        }
        // Drop any previous task first (e.g. switching hosts). Nil-ing it first
        // makes its trailing callbacks "stale" so they're ignored.
        let old = webSocketTask
        webSocketTask = nil
        old?.cancel(with: .goingAway, reason: nil)

        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        listenForMessages()
    }

    func disconnect() {
        shouldReconnect = false
        let task = webSocketTask
        webSocketTask = nil
        task?.cancel(with: .goingAway, reason: "Closing connection".data(using: .utf8))
        isConnected = false
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        guard webSocketTask === self.webSocketTask else { return }
        print("WebSocket Connected!")
        isConnected = true
        sendPing()
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("Disconnected: \(closeCode)")
        handleConnectionLost(webSocketTask)
    }

    // Hard failures (server down, network drop) arrive here, not in didCloseWith.
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { print("Connection failed: \(error.localizedDescription)") }
        handleConnectionLost(task)
    }

    /// Idempotent: only the first report for the current task does anything.
    private func handleConnectionLost(_ task: URLSessionTask) {
        guard task === webSocketTask else { return }   // stale or already handled
        webSocketTask = nil
        task.cancel()
        isConnected = false
        guard shouldReconnect else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self, self.shouldReconnect, self.webSocketTask == nil else { return }
            self.connect(url: self.url)
        }
    }

    func sendPing() {
        guard let task = webSocketTask else { return }
        task.sendPing { [weak self] error in
            guard let self, task === self.webSocketTask else { return }
            if let error {
                print("Ping failed: \(error)")
                self.handleConnectionLost(task)   // reconnects, unlike disconnect()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                    guard let self, task === self.webSocketTask else { return }
                    self.sendPing()
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
        send(.queueSong(QueueSong(song: song, append: append)))
    }
    
    func queueAlbum(album: Album, append: Bool = false) {
        send(.queueAlbum(QueueAlbum(album: album, append: append)))
    }
    
    func queuePlaylist(playlist: Playlist) {
        send(.queuePlaylist(QueuePlaylist(playlist: playlist)))
    }
    
    func queueStation(station: Station) {
        send(.queueStation(QueueStation(station: station)))
    }
    
    func runCommand(commandType: CommandType) {
        send(.command(CommandRequest(commandType: commandType)))
    }

    private func send(_ message: ClientMessage) {
        Task { @MainActor in
            do {
                let data = try JSONEncoder().encode(message)
                sendMessage(String(decoding: data, as: UTF8.self))
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
        guard let task = webSocketTask else { return }
        task.receive { [weak self] result in
            // Ignore results from a task we've already replaced or torn down.
            guard let strong = self, task === strong.webSocketTask else { return }
            switch result {
            case .failure(let error):
                print("Receive error: \(error.localizedDescription)")
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if self.isConnected {   // avoid a toast per failed retry
                        self.toastItem = ToastItem(
                            level: .error,
                            title: "Error",
                            message: error.localizedDescription
                        )
                    }
                    self.handleConnectionLost(task)
                }
            case .success(let message):
                switch message {
                case .string(let text):
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        do {
                            let msg = try JSONDecoder().decode(ServerMessage.self, from: Data(text.utf8))
                            switch msg {
                            case .status(let status):
                                self.expand(status: status)
                            case .queue(let queuestate):
                                self.queueChanged(queuestate: queuestate)
                            case .message(let msg):
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
                                self.toastItem = ToastItem(
                                    level: level,
                                    title: msg.title,
                                    message: msg.message
                                )
                            }
                        } catch {
                            print("Failed to decode server message: \(error)")
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
        // Newest state wins: cancel any in-flight resolve and start over, instead of
        // dropping this update while a previous one is still hitting the network.
        queueTask?.cancel()
        queueTask = Task { [weak self] in
            guard let self else { return }

            print("Queue changed enter")
            if !checkSong(song1: self.currentSong, song2: queuestate.currentSong) {
                if let current = queuestate.currentSong {
                    let resolved = await getSong(current)
                    guard !Task.isCancelled else { return }
                    self.currentSong = resolved
                }
            }
            if checkQueue(queuestate: queuestate) {
                print("Resetting Queue")
                self.queue.removeAll()
                for song in queuestate.songs {
                    let s = await getSong(song)
                    // A newer update owns the queue now; stop touching it. (A partially
                    // filled queue is fine: the newer update will see the mismatch and rebuild.)
                    guard !Task.isCancelled else { return }
                    if let s {
                        self.queue.append(s)
                    }
                }
            }
            if let x = queuestate.currentSong {
                for i in 0..<queue.count {
                    let y = queue[i]
                    if x.title == y.title && x.albumTitle == y.albumTitle && x.artistName == y.artistName {
                        currentIndex = i
                    }
                }
            }
            print("Queue changed exit")
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

