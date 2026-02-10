//
//  RegisterView.swift
//  EpusdtPay
//
//  User registration view
//

import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var phoneNumber = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var verificationCode = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showPassword = false

    var body: some View {
        ZStack {
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
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(Color(hex: 0xd4af37))
                    }
                    Spacer()
                    Text("Create Account")
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: 0xe6e6e6))
                    Spacer()
                    Color.clear.frame(width: 24)
                }
                .padding(16)

                // Form
                VStack(spacing: 16) {
                    // Phone
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Phone Number")
                            .font(.caption)
                            .foregroundColor(Color(hex: 0x999999))
                        TextField("Enter phone number", text: $phoneNumber)
                            .keyboardType(.phonePad)
                            .padding(12)
                            .background(Color(hex: 0x222a36))
                            .cornerRadius(8)
                    }

                    // Password
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.caption)
                            .foregroundColor(Color(hex: 0x999999))
                        SecureField("Enter password", text: $password)
                            .padding(12)
                            .background(Color(hex: 0x222a36))
                            .cornerRadius(8)
                    }

                    // Confirm Password
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm Password")
                            .font(.caption)
                            .foregroundColor(Color(hex: 0x999999))
                        SecureField("Confirm password", text: $confirmPassword)
                            .padding(12)
                            .background(Color(hex: 0x222a36))
                            .cornerRadius(8)
                    }

                    // Error
                    if !errorMessage.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundColor(Color(hex: 0xe74c3c))
                            Text(errorMessage)
                                .font(.caption)
                            Spacer()
                        }
                        .padding(12)
                        .background(Color(hex: 0xe74c3c).opacity(0.1))
                        .cornerRadius(8)
                    }

                    // Register Button
                    Button(action: registerUser) {
                        if isLoading {
                            ProgressView()
                                .tint(Color(hex: 0x171c25))
                        } else {
                            Text("Register")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(Color(hex: 0xd4af37))
                    .foregroundColor(Color(hex: 0x0f1218))
                    .cornerRadius(8)
                    .disabled(isLoading || phoneNumber.isEmpty || password.isEmpty)
                }
                .padding(20)
                .background(Color(hex: 0x171c25))
                .cornerRadius(12)
                .padding(20)

                Spacer()
            }
        }
        .navigationBarHidden(true)
    }

    private func registerUser() {
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            return
        }

        isLoading = true
        authViewModel.register(phone: phoneNumber, password: password) { success, error in
            DispatchQueue.main.async {
                isLoading = false
                if success {
                    dismiss()
                } else {
                    errorMessage = error ?? "Registration failed"
                }
            }
        }
    }
}

#Preview {
    RegisterView()
        .environmentObject(AuthViewModel())
}
