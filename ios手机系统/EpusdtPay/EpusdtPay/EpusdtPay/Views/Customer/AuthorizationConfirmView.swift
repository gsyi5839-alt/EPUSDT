//
//  AuthorizationConfirmView.swift
//  EpusdtPay
//
//  Authorization confirmation for customer payment
//

import SwiftUI
import Combine

struct AuthorizationConfirmView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var walletViewModel: WalletViewModel
    @StateObject private var confirmViewModel = AuthConfirmViewModel()

    let authUrl: String

    @State private var customerWallet: String = ""
    @State private var showingWalletInput = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Icon
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gold)
                        .padding(.top, 20)

                    // Title
                    VStack(spacing: 8) {
                        Text("Authorization Request")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.textPrimary)

                        Text("Review and confirm payment authorization")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }

                    // Authorization Info Card
                    if let info = confirmViewModel.authInfo {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Authorization Details")
                                .font(.headline)
                                .foregroundColor(.textPrimary)

                            Divider().background(Color.textSecondary.opacity(0.3))

                            InfoRow(label: "Authorization No.", value: info.authNo, valueColor: .gold)
                            InfoRow(label: "Password", value: info.password ?? "N/A", valueColor: .statusWarning)
                            InfoRow(label: "Amount (USDT)", value: String(format: "%.2f", info.authorizedUsdt), valueColor: .gold)

                            if let table = info.tableNo, !table.isEmpty {
                                InfoRow(label: "Table No.", value: table)
                            }

                            if let name = info.customerName, !name.isEmpty {
                                InfoRow(label: "Customer Name", value: name)
                            }

                            if let chain = info.chain {
                                HStack {
                                    Text("Blockchain")
                                        .font(.caption)
                                        .foregroundColor(.textSecondary)
                                    Spacer()
                                    ChainBadge(chain: chain)
                                }
                            }

                            if let wallet = info.merchantWallet {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Merchant Wallet")
                                        .font(.caption)
                                        .foregroundColor(.textSecondary)
                                    Text(wallet)
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundColor(.textPrimary)
                                        .lineLimit(2)
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.bgCard)
                        .cornerRadius(12)
                    }

                    // Wallet Input Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Wallet Address")
                            .font(.headline)
                            .foregroundColor(.textPrimary)

                        Text("Enter your USDT wallet address to authorize payments")
                            .font(.caption)
                            .foregroundColor(.textSecondary)

                        FormField(
                            label: "Wallet Address",
                            placeholder: "0x... or T...",
                            text: $customerWallet
                        )

                        Text("⚠️ Make sure you have sufficient USDT balance")
                            .font(.caption2)
                            .foregroundColor(.statusWarning)
                    }
                    .padding(16)
                    .background(Color.bgCard)
                    .cornerRadius(12)

                    // Warning Banner
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.statusInfo)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Authorization Note")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.statusInfo)
                            Text("The merchant can deduct from your wallet up to the authorized amount")
                                .font(.caption2)
                                .foregroundColor(.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.statusInfo.opacity(0.1))
                    .cornerRadius(8)

                    // Error/Success Messages
                    if let error = confirmViewModel.errorMessage {
                        ErrorBanner(message: error, onDismiss: {
                            confirmViewModel.errorMessage = nil
                        })
                    }

                    if let success = confirmViewModel.successMessage {
                        SuccessBanner(message: success)
                    }

                    // Action Buttons
                    VStack(spacing: 12) {
                        GoldButton(
                            title: "Confirm Authorization",
                            isLoading: confirmViewModel.isLoading,
                            action: {
                                confirmViewModel.confirmAuthorization(
                                    password: extractPassword(from: authUrl),
                                    customerWallet: customerWallet
                                )
                            }
                        )
                        .disabled(customerWallet.isEmpty)

                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("Cancel")
                                .fontWeight(.medium)
                                .foregroundColor(.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(14)
                                .background(Color.bgCard)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .navigationBarHidden(true)
            .darkBackground()
        }
        .onAppear {
            let password = extractPassword(from: authUrl)
            confirmViewModel.loadAuthInfo(password: password)
        }
        .alert(isPresented: $confirmViewModel.showingSuccess) {
            Alert(
                title: Text("Authorization Successful"),
                message: Text("Your wallet has been authorized for payments"),
                dismissButton: .default(Text("OK")) {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }

    private func extractPassword(from url: String) -> String {
        // Extract password from URL
        // Format: http://domain/auth?password=xxx or just password string
        if let urlComponents = URLComponents(string: url),
           let passwordParam = urlComponents.queryItems?.first(where: { $0.name == "password" })?.value {
            return passwordParam
        }
        // If URL parsing fails, assume the entire string is the password
        return url.components(separatedBy: "=").last ?? url
    }
}

// MARK: - Authorization Confirm ViewModel
class AuthConfirmViewModel: ObservableObject {
    @Published var authInfo: AuthorizationInfoResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var showingSuccess = false

    private let apiService = APIService.shared

    func loadAuthInfo(password: String) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let info = try await apiService.getAuthorizationInfo(password: password)
                await MainActor.run {
                    self.authInfo = info
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Failed to load authorization info: \(error.localizedDescription)"
                }
            }
        }
    }

    func confirmAuthorization(password: String, customerWallet: String) {
        guard !customerWallet.isEmpty else {
            errorMessage = "Please enter your wallet address"
            return
        }

        // Validate wallet address format
        if !isValidWalletAddress(customerWallet) {
            errorMessage = "Invalid wallet address format"
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil

        Task {
            do {
                // Call backend confirm API
                try await apiService.confirmAuthorization(
                    password: password,
                    customerWallet: customerWallet
                )

                await MainActor.run {
                    self.isLoading = false
                    self.successMessage = "Authorization confirmed successfully"
                    self.showingSuccess = true
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Authorization failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func isValidWalletAddress(_ address: String) -> Bool {
        // Basic validation for TRON (T...) and EVM (0x...) addresses
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("T") && trimmed.count == 34 {
            return true // TRON address
        }
        if trimmed.hasPrefix("0x") && trimmed.count == 42 {
            return true // EVM address
        }
        return false
    }
}
