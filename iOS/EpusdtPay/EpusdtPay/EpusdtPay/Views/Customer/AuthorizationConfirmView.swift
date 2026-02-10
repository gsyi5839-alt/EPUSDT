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

    /// 所有已启用的钱包
    private var enabledWallets: [WalletAddress] {
        walletViewModel.wallets.filter { $0.isEnabled }
    }

    var body: some View {
        mainContent
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(.gold)
                .padding(.top, 20)
            Text("授权请求")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.textPrimary)
            Text("确认支付授权")
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
    }

    // MARK: - Auth Info Card
    private func authInfoCard(info: AuthorizationInfoResponse) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("授权详情")
                .font(.headline)
                .foregroundColor(.textPrimary)
            Divider().background(Color.textSecondary.opacity(0.3))
            InfoRow(label: "授权编号", value: info.authNo, valueColor: .gold)
            InfoRow(label: "密码", value: info.password ?? "N/A", valueColor: .statusWarning)
            InfoRow(label: "金额 (USDT)", value: String(format: "%.2f", info.authorizedUsdt), valueColor: .gold)
            if let table = info.tableNo, !table.isEmpty {
                InfoRow(label: "桌号", value: table)
            }
            if let name = info.customerName, !name.isEmpty {
                InfoRow(label: "客户名", value: name)
            }
            if let chain = info.chain {
                HStack {
                    Text("区块链")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    Spacer()
                    ChainBadge(chain: chain)
                }
            }
            if let wallet = info.merchantWallet {
                VStack(alignment: .leading, spacing: 4) {
                    Text("商户钱包")
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

    // MARK: - Wallet Selection
    private var walletSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("钱包地址")
                .font(.headline)
                .foregroundColor(.textPrimary)
            if enabledWallets.isEmpty {
                Text("请先在钱包页面添加地址")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            } else if enabledWallets.count == 1 {
                singleWalletRow(wallet: enabledWallets[0])
            } else {
                ForEach(enabledWallets) { wallet in
                    walletSelectRow(wallet: wallet)
                }
            }
        }
        .padding(16)
        .background(Color.bgCard)
        .cornerRadius(12)
    }

    private func singleWalletRow(wallet: WalletAddress) -> some View {
        HStack {
            Text(wallet.token)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if let chain = wallet.chain {
                ChainBadge(chain: chain)
            }
        }
        .padding(12)
        .background(Color.bgCard.opacity(0.6))
        .cornerRadius(8)
    }

    private func walletSelectRow(wallet: WalletAddress) -> some View {
        let isSelected = customerWallet == wallet.token
        return Button(action: { customerWallet = wallet.token }) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .gold : .textSecondary)
                Text(wallet.token)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                if let chain = wallet.chain {
                    ChainBadge(chain: chain)
                }
            }
            .padding(10)
            .background(isSelected ? Color.gold.opacity(0.1) : Color.bgCard.opacity(0.6))
            .cornerRadius(8)
        }
    }

    // MARK: - Messages
    private var messagesSection: some View {
        VStack(spacing: 8) {
            if let error = confirmViewModel.errorMessage {
                ErrorBanner(message: error, onDismiss: {
                    confirmViewModel.errorMessage = nil
                })
            }
            if let success = confirmViewModel.successMessage {
                SuccessBanner(message: success)
            }
        }
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            GoldButton(
                title: "确认授权",
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
                Text("取消")
                    .fontWeight(.medium)
                    .foregroundColor(.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(Color.bgCard)
                    .cornerRadius(8)
            }
        }
    }

    // MARK: - Lifecycle & Modifiers
    private var mainContent: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    if let info = confirmViewModel.authInfo {
                        authInfoCard(info: info)
                    }
                    walletSelectionSection
                    messagesSection
                    actionButtons
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
            // 自动加载钱包并选中第一个
            if walletViewModel.wallets.isEmpty {
                walletViewModel.loadWallets()
            }
            // 自动选中第一个已启用的钱包
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if customerWallet.isEmpty, let first = enabledWallets.first {
                    customerWallet = first.token
                }
            }
        }
        .onChange(of: walletViewModel.wallets.map { $0.id }) {
            if customerWallet.isEmpty, let first = enabledWallets.first {
                customerWallet = first.token
            }
        }
        .alert(isPresented: $confirmViewModel.showingSuccess) {
            Alert(
                title: Text("授权成功"),
                message: Text("钱包已授权支付"),
                dismissButton: .default(Text("确定")) {
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
                // Use auto-confirm API (system verifies on-chain)
                let authNo = authInfo?.authNo ?? ""
                try await apiService.confirmAutoAuthorization(
                    authNo: authNo,
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
