//
//  LibraryStations.swift
//  AppleMusicBridgeClient
//
//  Created by Richard Backhouse on 3/2/25.
//

import SwiftUI
import MusicKit
import Combine

struct LibraryStations: View {
    @EnvironmentObject var viewModel: LibraryStationsModel
    @State private var searchQuery: String = ""

    var filteredStations: [Station] {
        if searchQuery.isEmpty {
            return viewModel.stations
        }
        return viewModel.stations.filter { station in
            station.name.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                loadingView()
                    .frame(maxHeight: 450)
            } else {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search Stations", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .modifier(ClearButton(text: $searchQuery))
                }
                .padding(8)
                #if os(iOS)
                .background(Color(.systemBackground))
                #elseif os(macOS)
                .background(Color(nsColor: .controlBackgroundColor))
                #endif
                .cornerRadius(8)
                .padding()
                
                // Results
                List(filteredStations) { station in
                    HStack(spacing: 8) {
                        StationCell(station)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Stations")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Text("\(filteredStations.count) stations")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .onAppear() {
            if viewModel.stations.isEmpty {
                viewModel.fetchStations()
            }
        }
    }
}

struct StationCell: View {
    init(_ station: Station) {
        self.station = station
    }
    
    let station: Station
    
    @State private var isPressed = false
    @State private var showQueuedFeedback = false
    
    var body: some View {
        MusicItemCell(
            artwork: station.artwork,
            title: station.name,
            subtitle: station.stationProviderName ?? ""
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
            
            WebSocketClient.shared.queueStation(station: station)
            withAnimation(.easeIn(duration: 0.2).delay(0.3)) {
                showQueuedFeedback = false
                isPressed = false
            }
        }
    }
}

@ViewBuilder
private func loadingView() -> some View {
    ProgressView()
        .scaleEffect(2)
        .tint(.blue)
}

class LibraryStationsModel: ObservableObject {
    @Published var stations: [MusicKit.Station] = []
    @Published var isLoading: Bool = false

    @MainActor
    func fetchStations() {
        Task {
            do {
                isLoading = true
                let request = MusicPersonalRecommendationsRequest()

                let response = try await request.response()
                for recommendation in response.recommendations {
                    for station in recommendation.stations {
                        if self.stations.contains(where: { $0.id == station.id }) {
                            continue
                        }
                        self.stations.append(station)
                    }
                }
                isLoading = false
            } catch {
                print("Error fetching stations: \(error)")
            }
        }
    }
}
