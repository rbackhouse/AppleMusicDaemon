//
//  MusicItemCell.swift
//  AppleMusicBridgeClient
//
//  Created by Richard Backhouse on 2/23/25.
//

import MusicKit
import SwiftUI

struct MusicItemCell: View {
    let artwork: Artwork?
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 12) {
            if let existingArtwork = artwork {
                ArtworkImage(existingArtwork, width: 48, height: 48)
                    .cornerRadius(4)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                
                Text(title)
                    .lineLimit(1)
                    .font(.body)
                
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .lineLimit(1)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
