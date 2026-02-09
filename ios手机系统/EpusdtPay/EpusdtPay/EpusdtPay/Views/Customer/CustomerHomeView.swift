//
//  CustomerHomeView.swift
//  EpusdtPay
//
//  Customer home with authorization scanning and management
//

import SwiftUI
import Combine

struct CustomerHomeView: View {
    @EnvironmentObject var walletViewModel: WalletViewModel
    @StateObject private var customerViewModel = CustomerViewModel()
    @State private var showingScanner = false
    @State private var showingAuthConfirm = false
    @State private var scannedAuthUrl: String?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Welcome Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("USDT 支付")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.textPrimary)

                        Text("扫码授权支付")
                            .font(.subheadline)
                            .foregroundColor(.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 20)

                    // Scan Button (Large)
                    Button(action: {
                        showingScanner = true
                    }) {
                        VStack(spacing: 16) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 60))
                                .foregroundColor(.gold)

                            VStack(spacing: 6) {
                                Text("扫描二维码")
                                    .font(.headline)
                                    .foregroundColor(.textPrimary)

                                Text("扫描商户授权码进行支付")
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.gold.opacity(0.15), Color.gold.opacity(0.05)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.gold.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 16)

                    // Recent Authorizations
                    if !customerViewModel.myAuthorizations.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("我的授权")
                                    .font(.headline)
                                    .foregroundColor(.textPrimary)
                                Spacer()
                                NavigationLink(destination: MyAuthorizationsView()) {
                                    Text("查看全部")
                                        .font(.caption)
                                        .foregroundColor(.gold)
                                }
                            }
                            .padding(.horizontal, 16)

                            ForEach(customerViewModel.myAuthorizations.prefix(3)) { auth in
                                AuthorizationCardView(authorization: auth)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }

                    // Features List
                    VStack(alignment: .leading, spacing: 12) {
                        Text("使用流程")
                            .font(.headline)
                            .foregroundColor(.textPrimary)
                            .padding(.horizontal, 16)

                        FeatureRow(
                            icon: "1.circle.fill",
                            title: "扫描二维码",
                            description: "扫描商户的授权二维码"
                        )

                        FeatureRow(
                            icon: "2.circle.fill",
                            title: "连接钱包",
                            description: "输入您的 USDT 钱包地址"
                        )

                        FeatureRow(
                            icon: "3.circle.fill",
                            title: "授权额度",
                            description: "商户可在授权额度内进行扣款"
                        )

                        FeatureRow(
                            icon: "4.circle.fill",
                            title: "获取通知",
                            description: "每笔扣款都会收到提醒通知"
                        )
                    }
                    .padding(.top, 10)
                }
                .padding(.bottom, 30)
            }
            .navigationBarHidden(true)
            .darkBackground()
        }
        .sheet(isPresented: $showingScanner) {
            QRCodeScannerView(scannedAuthUrl: $scannedAuthUrl)
        }
        .sheet(isPresented: $showingAuthConfirm) {
            if let url = scannedAuthUrl {
                AuthorizationConfirmView(authUrl: url)
            }
        }
        .onChange(of: scannedAuthUrl) {
            if scannedAuthUrl != nil {
                showingAuthConfirm = true
            }
        }
        .onAppear {
            customerViewModel.loadMyAuthorizations()
        }
    }
}

// MARK: - Authorization Card View
struct AuthorizationCardView: View {
    let authorization: KtvAuthorization

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("授权 #\(String(authorization.authNo.suffix(8)))")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.gold)

                    if let table = authorization.tableNo {
                        Text("桌号: \(table)")
                            .font(.caption2)
                            .foregroundColor(.textSecondary)
                    }
                }

                Spacer()

                StatusBadge(authStatus: authorization.status)
            }

            Divider().background(Color.textSecondary.opacity(0.2))

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("已授权")
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                    Text(String(format: "%.2f USDT", authorization.authorizedUsdt))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.gold)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("已使用")
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                    Text(String(format: "%.2f", authorization.usedUsdt))
                        .font(.caption)
                        .foregroundColor(.statusWarning)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("剩余")
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                    Text(String(format: "%.2f", authorization.remainingUsdt))
                        .font(.caption)
                        .foregroundColor(.statusSuccess)
                }
            }

            if let chain = authorization.chain {
                ChainBadge(chain: chain)
            }
        }
        .padding(14)
        .background(Color.bgCard)
        .cornerRadius(12)
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.gold)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.textPrimary)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Customer ViewModel
class CustomerViewModel: ObservableObject {
    @Published var myAuthorizations: [KtvAuthorization] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiService = APIService.shared

    var activeAuthCount: Int {
        myAuthorizations.filter { $0.status == 2 }.count
    }

    var totalAuthorizedUsdt: Double {
        myAuthorizations.reduce(0) { $0 + $1.authorizedUsdt }
    }

    func loadMyAuthorizations() {
        // In a real app, this would filter by customer wallet
        // For now, we'll load all authorizations as a demo
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let auths = try await apiService.fetchAuthorizations()
                await MainActor.run {
                    self.myAuthorizations = auths
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
