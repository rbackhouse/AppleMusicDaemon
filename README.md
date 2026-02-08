# Apple Music Daemon

### SwiftUI apps for Apple Music control: daemon, macOS client, and iOS controller

The project comprises three separate Swift applications, including two macOS-targeted apps and one iOS app.

The goal is to enable running a headless Apple Music controller on an Apple‑based computer connected to a home stereo. 

* A Daemon application (macos) runs on the headless computer to control play and retrieve current queue information from the Apple Music installation
* A Client application (macos) runs on other apple based computers that connects to the Daemon to visually show the current queue, control what is playing and interact directly with Apple Music to obtain library data.
* A Control application (ios) that performs the same function as the Client except that it runs on iOS devices.

Communication between client/controller and the daemon is via WebSockets. The Daemon publishes its detail via a Bonjour Service. When the client apps are started they attempt to discover Daemon instances running on your load network.

### Building

* Load AMD.xcworkspace in xcode, the 3 separate projects are part of this workspace.
* AppleMusicDaemon.xcodeproj is the headless Daemon Application
* AppleMusicDaemonClient.xcodeproj is the client for macos
* AppleMusicDaemonCtrl.xcodeproj is the client for iOS

#### Notes
* AppleMusicDaemonCtrl uses common shared files from AppleMusicDaemonClient
* All running apps need a Apple Music instance with a valid Apple Music Subscription.
