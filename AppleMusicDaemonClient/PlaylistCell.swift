//
//  PlaylistCell.swift
//  AppleMusicBridgeClient
//
//  Created by Richard Backhouse on 3/1/25.
//

import SwiftUI
import MusicKit

struct PlaylistCell: View {
    init(_ playlist: Playlist) {
        self.playlist = playlist
    }
    
    let playlist: Playlist
    
    var body: some View {
        NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
            MusicItemCell(
                artwork: playlist.artwork,
                title: playlist.name,
                subtitle: ""
            )
        }
    }
}

