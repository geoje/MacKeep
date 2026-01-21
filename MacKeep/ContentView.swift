import SwiftUI

struct ContentView: View {
  @State private var email: String = ""
  @State private var masterToken: String = ""
  @State private var oauthToken: String = ""
  @State private var useOAuthToken: Bool = false
  @State private var showAlert = false
  @State private var alertMessage = ""
  @State private var isLoading = false
  @State private var isSuccess = false
  @State private var debugLogs: [String] = []

  private let defaults = UserDefaults(suiteName: "group.kr.ygh.MacKeep")!

  var body: some View {
    VStack(spacing: 16) {
      inputField("Email", "example@gmail.com", text: $email)
      authMethodToggle()
      if useOAuthToken {
        oauthTokenField()
      } else {
        tokenField()
      }
      connectButton()
      debugLogView()
    }
    .padding(16)
    .frame(minWidth: 240, maxWidth: .infinity, minHeight: 320, maxHeight: .infinity)
    .alert(isSuccess ? "✅ Success" : "❌ Error", isPresented: $showAlert) {
      Button("OK") {}
    } message: {
      Text(alertMessage)
    }
    .onAppear {
      // App Group에서 저장된 값 로드
      email = defaults.string(forKey: "email") ?? ""
      masterToken = defaults.string(forKey: "masterToken") ?? ""
    }
  }

  private func inputField(_ label: String, _ placeholder: String, text: Binding<String>)
    -> some View
  {
    VStack(alignment: .leading, spacing: 8) {
      Label(label, systemImage: "envelope")
        .fontWeight(.semibold)
      TextField(placeholder, text: text)
        .textFieldStyle(.roundedBorder)
    }
  }

  private func authMethodToggle() -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Label("Authentication Method", systemImage: "lock.shield")
        .fontWeight(.semibold)
      Picker("", selection: $useOAuthToken) {
        Text("Master Token").tag(false)
        Text("OAuth Token").tag(true)
      }
      .pickerStyle(.segmented)
    }
  }

  private func oauthTokenField() -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Label("OAuth Token (from browser)", systemImage: "key")
          .fontWeight(.semibold)
        Spacer()
        Button(action: {
          NSWorkspace.shared.open(
            URL(string: "https://github.com/rukins/gpsoauth-java/blob/master/README.md#second-way")!
          )
        }) {
          Image(systemName: "questionmark.circle")
            .foregroundColor(.gray)
            .font(.system(size: 14))
        }
        .buttonStyle(.plain)
        .cursorHover()
      }
      SecureField("oauth2_4/**", text: $oauthToken)
        .textFieldStyle(.roundedBorder)
      Text("Copy from browser cookies at accounts.google.com/EmbeddedSetup")
        .font(.caption)
        .foregroundColor(.gray)
    }
  }

  private func tokenField() -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Label("Master Token", systemImage: "key")
          .fontWeight(.semibold)
        Spacer()
        Button(action: {
          NSWorkspace.shared.open(
            URL(string: "https://github.com/rukins/gpsoauth-java/blob/master/README.md#second-way")!
          )
        }) {
          Image(systemName: "questionmark.circle")
            .foregroundColor(.gray)
            .font(.system(size: 14))
        }
        .buttonStyle(.plain)
        .cursorHover()
      }
      SecureField("aas_et/**", text: $masterToken)
        .textFieldStyle(.roundedBorder)
    }
  }

  private func connectButton() -> some View {
    Button(action: loginToKeep) {
      HStack(spacing: 4) {
        Text("Connect")
        if isLoading {
          ProgressView()
            .progressViewStyle(.circular)
            .frame(width: 8, height: 8)
            .scaleEffect(0.4)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(8)
      .background(.blue)
      .foregroundColor(.white)
      .cornerRadius(6)
      .font(.system(.body, design: .default, weight: .semibold))
    }
    .buttonStyle(.plain)
    .cursorHover()
    .disabled(isLoading)
  }

  private func debugLogView() -> some View {
    Group {
      if !debugLogs.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Label("Debug Logs", systemImage: "terminal")
              .fontWeight(.semibold)
            Spacer()
            Button(action: { debugLogs.removeAll() }) {
              Image(systemName: "trash")
                .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
          }
          ScrollViewReader { proxy in
            ScrollView {
              Text(debugLogs.joined(separator: "\n"))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .textSelection(.enabled)
                .id("logBottom")
            }
            .onChange(of: debugLogs) { oldValue, newValue in
              proxy.scrollTo("logBottom", anchor: .bottom)
            }
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .padding(8)
          .background(Color(.sRGBLinear, red: 0.95, green: 0.95, blue: 0.95))
          .cornerRadius(4)
          .border(Color.gray.opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
  }

  private func addLog(_ message: String) {
    let timestamp = DateFormatter.localizedString(
      from: Date(), dateStyle: .none, timeStyle: .medium)
    let logMessage = "[\(timestamp)] \(message)"
    debugLogs.append(logMessage)
  }

  private func loginToKeep() {
    isLoading = true
    debugLogs.removeAll()

    let gpsAuthAPI = GPSAuthAPI()
    gpsAuthAPI.onLog = self.addLog

    let deviceId = UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "").prefix(16)
      .uppercased()

    if useOAuthToken {
      // Flow: OAuth Token -> Master Token -> Access Token -> Notes
      addLog("Using OAuth token to retrieve master token...")
      gpsAuthAPI.exchangeToken(email: email, oauthToken: oauthToken, deviceId: String(deviceId)) {
        result in
        DispatchQueue.main.async {
          switch result {
          case .success(let retrievedMasterToken):
            self.addLog("Successfully retrieved master token from OAuth token")
            // Save the master token for future use
            self.masterToken = retrievedMasterToken
            self.defaults.set(retrievedMasterToken, forKey: "masterToken")
            // Now use the master token to get access token
            self.performOAuthWithMasterToken(
              gpsAuthAPI: gpsAuthAPI, masterToken: retrievedMasterToken, deviceId: String(deviceId))
          case .failure(let error):
            self.showError("Failed to exchange OAuth token: \(error.localizedDescription)")
          }
        }
      }
    } else {
      // Flow: Master Token -> Access Token -> Notes
      performOAuthWithMasterToken(
        gpsAuthAPI: gpsAuthAPI, masterToken: masterToken, deviceId: String(deviceId))
    }
  }

  private func performOAuthWithMasterToken(
    gpsAuthAPI: GPSAuthAPI, masterToken: String, deviceId: String
  ) {
    gpsAuthAPI.performOAuth(email: email, masterToken: masterToken, deviceId: deviceId) {
      result in
      DispatchQueue.main.async {
        switch result {
        case .success(let authToken):
          // Save email, masterToken, authToken to shared UserDefaults
          self.defaults.set(self.email, forKey: "email")
          self.defaults.set(masterToken, forKey: "masterToken")
          self.defaults.set(authToken, forKey: "authToken")

          let keepAPI = GoogleKeepAPI()
          keepAPI.onLog = self.addLog
          keepAPI.fetchNotes(authToken: authToken) { notesResult in
            DispatchQueue.main.async {
              self.isLoading = false
              switch notesResult {
              case .success(let notes):
                // Save notes for the widget via shared UserDefaults
                if let data = try? JSONEncoder().encode(notes) {
                  self.defaults.set(data, forKey: "nodes")
                }

                let filteredNotes = notes.filter {
                  $0.parentId == "root" && ($0.isArchived ?? false) == false
                    && ($0.timestamps?.trashed == nil || !$0.timestamps!.trashed!.starts(with: "2"))
                }
                self.alertMessage =
                  "\(filteredNotes.count) notes found\n\nNow try adding a widget from Notification Center or your Desktop!"
                self.isSuccess = true
                self.showAlert = true
              case .failure(let error):
                self.showError(error.localizedDescription)
              }
            }
          }
        case .failure(let error):
          self.showError(error.localizedDescription)
        }
      }
    }
  }

  private func showError(_ message: String) {
    DispatchQueue.main.async {
      self.isLoading = false
      self.alertMessage = message
      self.isSuccess = false
      self.showAlert = true
    }
  }
}

extension View {
  func cursorHover() -> some View {
    onHover { hovering in
      hovering ? NSCursor.pointingHand.push() : NSCursor.pop()
    }
  }
}

#Preview {
  ContentView()
}
