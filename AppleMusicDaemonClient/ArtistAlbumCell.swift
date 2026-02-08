//
//  ArtistAlbumCell.swift
//  AppleMusicBridgeClient
//
//  Created by Richard Backhouse on 3/1/25.
//

import MusicKit
import SwiftUI

struct ArtistAlbumCell: View {
    init(_ album: Album, from artist: Artist) {
        self.artist = artist
        self.album = album
    }
    
    let artist: Artist
    let album: Album
    
    var body: some View {
            MusicItemCell(
                artwork: album.artwork,
                title: album.title,
                subtitle: artist.name
            )
            .frame(minHeight: 50)
    }
}
