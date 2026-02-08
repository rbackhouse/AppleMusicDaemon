//
//  AlbumCell.swift
//  AppleMusicBridgeClient
//
//  Created by Richard Backhouse on 2/23/25.
//

import SwiftUI
import MusicKit

struct AlbumCell: View {
    init(_ album: Album) {
        self.album = album
    }
    
    let album: Album
    
    var body: some View {
        NavigationLink(destination: AlbumDetailView(album)) {
            MusicItemCell(
                artwork: album.artwork,
                title: album.title,
                subtitle: album.artistName
            )
        }
    }    
}
