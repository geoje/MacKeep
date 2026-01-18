import SwiftUI

struct ContentView: View {
  @AppStorage("email") var email: String = ""
  @AppStorage("masterToken") var masterToken: String = ""
  @State private var showAlert = false
  @State private var alertMessage = ""
  @State private var isLoading = false
  @State private var isSuccess = false
  @State private var debugLogs: [String] = []

  var body: some View {
    VStack(spacing: 16) {
      inputField("Email", "example@gmail.com", text: $email)
      tokenField()
      connectButton()
      debugLogView()
    }
    .padding(16)
    .frame(minWidth: 280, maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)
    .alert(isSuccess ? "✅ Success" : "❌ Error", isPresented: $showAlert) {
      Button("OK") {}
    } message: {
      Text(alertMessage)
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
          ScrollView {
            Text(debugLogs.joined(separator: "\n"))
              .font(.system(size: 10, design: .monospaced))
              .foregroundColor(.gray)
              .frame(maxWidth: .infinity, alignment: .topLeading)
              .textSelection(.enabled)
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
    if debugLogs.count > 50 {
      debugLogs.removeFirst()
    }
  }

  private func loginToKeep() {
    isLoading = true
    let api = GoogleKeepAPI(email: email, masterToken: masterToken)
    api.onLog = { message in
      DispatchQueue.main.async { self.addLog(message) }
    }

    api.getOAuthToken { result in
      DispatchQueue.main.async {
        switch result {
        case .success:
          api.GoogleKeepAPI { notesResult in
            DispatchQueue.main.async { self.handleFetchResult(notesResult) }
          }
        case .failure(let error):
          self.showError(error.localizedDescription)
        }
      }
    }
  }

  private func handleFetchResult(_ result: Result<Int, Error>) {
    isLoading = false
    switch result {
    case .success(let count):
      alertMessage = "\(count) notes found"
      isSuccess = true
    case .failure(let error):
      alertMessage = error.localizedDescription
      isSuccess = false
    }
    showAlert = true
  }

  private func showError(_ message: String) {
    DispatchQueue.main.async {
      isLoading = false
      alertMessage = message
      isSuccess = false
      showAlert = true
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
