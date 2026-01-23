import SwiftUI

@main
struct MacKeepApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
        .onOpenURL { url in
          // Handle widgetURL by opening Google Keep in the default browser
          NSWorkspace.shared.open(url)
        }
    }
    .windowResizability(.contentSize)
  }
}
