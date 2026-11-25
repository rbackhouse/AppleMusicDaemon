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
    case setShuffle(Bool)
    case setRepeat(Bool)
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
    private var queueEntryIDs: [String] = []
    private var songCache: [MusicItemID: Song] = [:]
    // The server only resyncs the position every few seconds; we advance it locally in between.
    private var baseTime: Double = 0
    private var baseDate = Date()
    private var clockTask: Task<Void, Never>?
    private var shouldReconnect = false
    private var authToken: String?
    private var reconnectAttempts = 0

    func connect(url: URL, token: String? = nil) {
        shouldReconnect = true
        self.url = url
        self.authToken = token
        if session == nil {
            session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        }
        // Drop any previous task first (e.g. switching hosts). Nil-ing it first
        // makes its trailing callbacks "stale" so they're ignored.
        let old = webSocketTask
        webSocketTask = nil
        old?.cancel(with: .goingAway, reason: nil)

        var request = URLRequest(url: url)
        if let token = authToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        listenForMessages()
    }

    func disconnect() {
        shouldReconnect = false
        reconnectAttempts = 0
        let task = webSocketTask
        webSocketTask = nil
        task?.cancel(with: .goingAway, reason: "Closing connection".data(using: .utf8))
        isConnected = false
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        guard webSocketTask === self.webSocketTask else { return }
        print("WebSocket Connected!")
        isConnected = true
        reconnectAttempts = 0
        sendPing()
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("Disconnected: \(closeCode)")
        handleConnectionLost(webSocketTask)
    }

    // Hard failures (server down, network drop) arrive here, not in didCloseWith.
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { print("Connection failed: \(error.localizedDescription)") }
        if task === webSocketTask, (task.response as? HTTPURLResponse)?.statusCode == 401 {
            shouldReconnect = false   // retrying with the same token can't succeed
            toastItem = ToastItem(
                level: .error,
                title: "Authentication Failed",
                message: "The server rejected the token."
            )
        }
        handleConnectionLost(task)
    }

    /// Idempotent: only the first report for the current task does anything.
    private func handleConnectionLost(_ task: URLSessionTask) {
        guard task === webSocketTask else { return }   // stale or already handled
        webSocketTask = nil
        task.cancel()
        isConnected = false
        guard shouldReconnect else { return }
        let delay = min(2.0 * pow(2.0, Double(reconnectAttempts)), 30.0)
        reconnectAttempts += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.shouldReconnect, self.webSocketTask == nil else { return }
            self.connect(url: self.url, token: self.authToken)
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
        send(.setShuffle(!isShuffleOn))
    }
    
    func repeatMode() {
        send(.setRepeat(!isRepeatModeOn))
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
        guard let task = webSocketTask else {
            print("Send skipped: not connected")
            Task { @MainActor in
                self.toastItem = ToastItem(
                    level: .warning,
                    title: "Not Connected",
                    message: "Couldn't reach the server. Reconnecting..."
                )
            }
            return
        }
        let message = URLSessionWebSocketTask.Message.string(message)
        task.send(message) { error in
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
                    print("Received unknown message type")
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
            let ids = queuestate.entries.map(\.id)
            if ids != self.queueEntryIDs {
                print("Resetting Queue")
                let resolved = await self.resolveSongs(queuestate.entries.map(\.song))
                guard !Task.isCancelled else { return }
                self.queue = queuestate.entries.map { resolved[$0.song.id] ?? $0.song }
                self.queueEntryIDs = ids
            }
            if let current = queuestate.currentEntryID, let index = ids.firstIndex(of: current) {
                self.currentIndex = index
                self.currentSong = self.queue[index]
            }
            print("Queue changed exit")
        }
    }
    
    @MainActor
    func expand(status: StatusResponse) {
        baseTime = status.playbackTime
        baseDate = Date()
        // Assign only on change so unchanged fields don't republish.
        if playbackStatus != status.playbackStatus { playbackStatus = status.playbackStatus }
        if isRepeatModeOn != status.repeatStatus { isRepeatModeOn = status.repeatStatus }
        if isShuffleOn != status.shuffleStatus { isShuffleOn = status.shuffleStatus }
        refreshClock()
        if clockTask == nil {
            startClock()
        }
    }

    /// Recomputes position and labels from the last server sync plus elapsed local time.
    @MainActor
    private func refreshClock() {
        var time = baseTime
        if playbackStatus == .playing {
            time += Date().timeIntervalSince(baseDate)
        }
        if let duration = currentSong?.duration {
            time = min(time, duration)
        }
        time = time.rounded(.down)
        let duration = (currentSong?.duration ?? 0).rounded(.down)

        let mins = (time / 60).rounded(.down)
        let secs = time - mins * 60
        let dmins = (duration / 60).rounded(.down)
        let dsecs = duration - dmins * 60
        let timeLabel = String(format: "%02d:%02d", Int(mins), Int(secs))
        let durationLabel = String(format: "%02d:%02d", Int(dmins), Int(dsecs))

        if playbackTime != time { playbackTime = time }
        if playbackDuration != duration { playbackDuration = duration }
        if playbackTimeLabel != timeLabel { playbackTimeLabel = timeLabel }
        if playbackDurationLabel != durationLabel { playbackDurationLabel = durationLabel }
    }

    @MainActor
    private func startClock() {
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self else { return }
                if self.isConnected && self.playbackStatus == .playing {
                    self.refreshClock()
                }
            }
        }
    }
    
    /// Resolves songs to full catalog objects with one request per 25 ids, caching by id.
    /// Anything the catalog doesn't know (e.g. library-only songs) is simply left out of the
    /// result, and callers fall back to the song they were sent.
    @MainActor
    private func resolveSongs(_ songs: [Song]) async -> [MusicItemID: Song] {
        var result: [MusicItemID: Song] = [:]
        var missing: [MusicItemID] = []
        for song in songs {
            if let cached = songCache[song.id] {
                result[song.id] = cached
            } else if !missing.contains(song.id) {
                missing.append(song.id)
            }
        }

        var start = 0
        while start < missing.count {
            if Task.isCancelled { break }
            let chunk = Array(missing[start..<min(start + 25, missing.count)])
            start += 25
            do {
                let request = MusicCatalogResourceRequest<Song>(matching: \.id, memberOf: chunk)
                let response = try await request.response()
                for song in response.items {
                    result[song.id] = song
                    songCache[song.id] = song
                }
            } catch {
                print("Batch song lookup failed: \(error)")
            }
        }
        return result
    }
}

