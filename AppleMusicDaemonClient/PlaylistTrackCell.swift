//
//  PlaylistTrackCell.swift
//  AppleMusicBridgeClient
//
//  Created by Richard Backhouse on 3/1/25.
//

import SwiftUI
import MusicKit

struct PlaylistTrackCell: View {
    init(_ track: Track, from playlist: Playlist) {
        self.track = track
        self.playlist = playlist
    }
    
    let track: Track
    let playlist: Playlist
    @State private var isPressed = false
    @State private var showQueuedFeedback = false
    
    var body: some View {
        MusicItemCell(
            artwork: nil,
            title: track.title,
            subtitle: track.artistName
        )
        .frame(minHeight: 50)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .opacity(showQueuedFeedback ? 0.5 : 1.0)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
            
            withAnimation(.easeOut(duration: 0.2).delay(0.1)) {
                showQueuedFeedback = true
            }
            
            switch track {
            case .song(let s):
                WebSocketClient.shared.queueSong(song: s)
            case .musicVideo(_):
                break
            @unknown default:
                break
            }
            
            withAnimation(.easeIn(duration: 0.2).delay(0.3)) {
                showQueuedFeedback = false
                isPressed = false
            }
        }
        .contextMenu {
            Button {
                withAnimation {
                    switch track {
                    case .song(let s):
                        WebSocketClient.shared.queueSong(song: s, append: true)
                    case .musicVideo(_):
                        break
                    @unknown default:
                        break
                    }
                }
            } label: {
                Label("Append to Queue", systemImage: "plus.arrow.trianglehead.clockwise")
            }
        }
    }
}
