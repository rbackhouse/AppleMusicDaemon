//
//  ArtistCell.swift
//  AppleMusicBridgeClient
//
//  Created by Richard Backhouse on 3/1/25.
//

import SwiftUI
import MusicKit

struct ArtistCell: View {
    init(_ artist: Artist) {
        self.artist = artist
    }
    
    let artist: Artist
    
    var body: some View {
        NavigationLink(destination: ArtistDetailView(artist)) {
            MusicItemCell(
                artwork: artist.artwork,
                title: artist.name,
                subtitle: ""
            )
        }
    }
}
