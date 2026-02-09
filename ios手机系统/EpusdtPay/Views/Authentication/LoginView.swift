//
//  LoginView.swift
//  EpusdtPay
//
//  User authentication and login view
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var username = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var isLoading = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hex: 0x0f1218),
                        Color(hex: 0x171c25)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Logo & Title
                    VStack(spacing: 12) {
                        Image(systemName: "bitcoinsign.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: 0xd4af37))

                        Text("Epusdt Pay")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(Color(hex: 0xe6e6e6))

                        Text("Easy Payment USDT")
                            .font(.caption)
                            .foregroundColor(Color(hex: 0x999999))
                    }
                    .padding(.top, 40)

                    // Form
                    VStack(spacing: 16) {
                        // Username Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Username")
                                .font(.caption)
                                .foregroundColor(Color(hex: 0x999999))

                            TextField("Enter username", text: $username)
                                .textContentType(.username)
                                .autocapitalization(.none)
                                .padding(12)
                                .background(Color(hex: 0x222a36))
                                .cornerRadius(8)
                                .foregroundColor(Color(hex: 0xe6e6e6))
                        }

                        // Password Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.caption)
                                .foregroundColor(Color(hex: 0x999999))

                            HStack {
                                if showPassword {
                                    TextField("Enter password", text: $password)
                                        .textContentType(.password)
                                } else {
                                    SecureField("Enter password", text: $password)
                                }

                                Button(action: { showPassword.toggle() }) {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundColor(Color(hex: 0x999999))
                                }
                            }
                            .padding(12)
                            .background(Color(hex: 0x222a36))
                            .cornerRadius(8)
                        }

                        // Error Message
                        if !errorMessage.isEmpty {
                            HStack {
                                Image(systemName: "exclamationmark.circle")
                                    .foregroundColor(Color(hex: 0xe74c3c))
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(Color(hex: 0xe74c3c))
                                Spacer()
                            }
                            .padding(12)
                            .background(Color(hex: 0xe74c3c).opacity(0.1))
                            .cornerRadius(8)
                        }

                        // Login Button
                        Button(action: loginUser) {
                            if isLoading {
                                ProgressView()
                                    .tint(Color(hex: 0x171c25))
                            } else {
                                Text("Login")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(Color(hex: 0xd4af37))
                        .foregroundColor(Color(hex: 0x0f1218))
                        .cornerRadius(8)
                        .disabled(isLoading || username.isEmpty || password.isEmpty)
                    }
                    .padding(20)
                    .background(Color(hex: 0x171c25))
                    .cornerRadius(12)

                    // Account Access Info
                    HStack(spacing: 4) {
                        Text("Don't have account?")
                            .foregroundColor(Color(hex: 0x999999))
                        Text("Contact administrator")
                            .foregroundColor(Color(hex: 0xd4af37))
                    }
                    .font(.caption)

                    Spacer()
                }
                .padding(20)
            }
            .navigationBarHidden(true)
        }
    }

    private func loginUser() {
        isLoading = true
        authViewModel.login(username: username, password: password) { success, error in
            DispatchQueue.main.async {
                isLoading = false
                if !success {
                    errorMessage = error ?? "Login failed"
                }
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}

// MARK: - Color Extension
extension Color {
    init(hex: Int) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}
