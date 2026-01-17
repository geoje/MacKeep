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
                KeychainHelper.standard.save(masterToken, forKey: "GoogleMasterToken")
                alertMessage = "0 notes found"
                showAlert = true
            }) {
                Text("Connect")
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(.blue)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                    .font(.system(.body, design: .default, weight: .semibold))
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
        .padding(16)
        .frame(width: 240)
        .onAppear {
            if let token = KeychainHelper.standard.retrieve(forKey: "GoogleMasterToken") {
                masterToken = token
            }
        }
        .alert("Success", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
}

#Preview {
    ContentView()
}
