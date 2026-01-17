//
//  ContentView.swift
//  MacKeep
//
//  Created by Gyeongho Yang on 17.01.26.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("email") var email: String = ""
    @State private var masterToken: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var isSuccess = false
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Email", systemImage: "envelope")
                    .fontWeight(.semibold)
                TextField("example@gmail.com", text: $email)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Master Token", systemImage: "key")
                        .fontWeight(.semibold)
                    
                    Button(action: {
                        if let url = URL(string: "https://github.com/rukins/gpsoauth-java/blob/master/README.md#second-way") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(.gray)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    
                    Spacer()
                }
                
                SecureField("aas_et/**", text: $masterToken)
                    .textFieldStyle(.roundedBorder)
            }
            
            Button(action: {
                loginToKeep()
            }) {
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
            .onHover { hovering in
                if hovering && !isLoading {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            .disabled(isLoading)
        }
        .padding(16)
        .frame(width: 240)
        .onAppear {
            if let token = KeychainHelper.standard.retrieve(forKey: "GoogleMasterToken") {
                masterToken = token
            }
        }
        .alert(isSuccess ? "✅ Success" : "❌ Error", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    func loginToKeep() {
        isLoading = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let api = GoogleKeepAPI(email: email, masterToken: masterToken)
            api.fetchNotes { result in
                DispatchQueue.main.async {
                    isLoading = false
                    
                    switch result {
                    case .success(let notes):
                        KeychainHelper.standard.save(masterToken, forKey: "GoogleMasterToken")
                        alertMessage = "\(notes.count) notes found"
                        isSuccess = true
                        showAlert = true
                        
                    case .failure(let error):
                        alertMessage = "Error: \(error.localizedDescription)"
                        isSuccess = false
                        showAlert = true
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
