//
//  ContentView.swift
//  AppleMusicDaemon
//
//  Created by Richard Backhouse on 12/21/25.
//

import SwiftUI
import MusicKit
import Combine

struct ContentView: View {
    @StateObject private var bonjourService = BonjourService()
    @StateObject private var viewModel = MusicViewModel()
    @State var amo: AppleMusicObservable = AppleMusicObservable()

    var body: some View {
        VStack {
            Text("Now Playing: \(viewModel.currentSong)")
                .font(.largeTitle)
        }
        .padding()
        .onAppear() {
            bonjourService.startStop()
        }
        //.onChange(of: bonjourService.serviceName) { oldValue, newValue in
        //}
        .task {
            let server: AppleMusicDaemon = AppleMusicDaemon(addWS: amo.addWS, removeWS: amo.removeWS, sendMessage: amo.sendMessage)
            do {
                Task {
                    try await amo.startTimer()
                }
                try await server.startAsync()
            } catch {
                fatalError(error.localizedDescription)
            }
        }
    }
}

class MusicViewModel: ObservableObject {
    var queueObserver: AnyCancellable?
    @Published var currentSong: String = ""

    init() {
        let musicPlayer = ApplicationMusicPlayer.shared
        self.queueObserver = musicPlayer.queue.objectWillChange
           .sink { [weak self] in
               self?.queueDidChange()
           }
    }
    
    func requestAuthorization() {
        Task {
            let status = await MusicAuthorization.request()
            switch status {
            case .authorized:
                print("Authorized")
                let sub = try await MusicSubscription.current
                if sub.canPlayCatalogContent {
                    print("Can play catalog content")
                }
                if sub.hasCloudLibraryEnabled {
                    print("Has cloud library enabled")
                }
            default:
                print("Not authorized")
            }
        }
    }
    
    private func queueDidChange() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: {
            let player = ApplicationMusicPlayer.shared
            let currentSong = player.queue.currentEntry?.title ?? "Unknown"
            self.currentSong = currentSong
        })
    }
}

