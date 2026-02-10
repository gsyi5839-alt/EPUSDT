//
//  CustomerHomeView.swift
//  EpusdtPay
//
//  Customer home with authorization scanning and QR code display
//

import SwiftUI
import Combine
import CoreImage.CIFilterBuiltins

struct CustomerHomeView: View {
    @EnvironmentObject var walletViewModel: WalletViewModel
    @StateObject private var customerViewModel = CustomerViewModel()
    @State private var showingScanner = false
    @State private var showingAuthConfirm = false
    @State private var scannedAuthUrl: String?
    @State private var showCopiedAlert = false
    @State private var showSavedAlert = false

    /// 所有已启用的钱包
    private var enabledWallets: [WalletAddress] {
        walletViewModel.wallets.filter { $0.isEnabled }
    }

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

                        Text(enabledWallets.isEmpty ? "扫码授权支付" : "收款二维码")
                            .font(.subheadline)
                            .foregroundColor(.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 20)

                    // MARK: - Wallet QR Codes (auto-generated)
                    if walletViewModel.isLoading {
                        ProgressView("加载钱包...")
                            .progressViewStyle(CircularProgressViewStyle(tint: .gold))
                            .padding(30)
                    } else if !enabledWallets.isEmpty {
                        // 展示每个已启用钱包的二维码
                        ForEach(enabledWallets) { wallet in
                            walletQRCodeCard(wallet: wallet)
                                .padding(.horizontal, 16)
                        }
                    } else {
                        // 无钱包时显示扫描按钮
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

                        // 无钱包提示
                        VStack(spacing: 8) {
                            Image(systemName: "wallet.pass")
                                .font(.system(size: 32))
                                .foregroundColor(.textSecondary)
                            Text("请先在「钱包」页面添加收款地址")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                            Text("添加后将自动生成收款二维码")
                                .font(.caption2)
                                .foregroundColor(.textSecondary.opacity(0.7))
                        }
                        .padding(.top, 4)
                    }

                    // Scan Button (small, when wallets exist)
                    if !enabledWallets.isEmpty {
                        Button(action: {
                            showingScanner = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "qrcode.viewfinder")
                                    .font(.system(size: 18))
                                Text("扫描商户二维码")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.gold)
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(Color.gold.opacity(0.1))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gold.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, 16)
                    }

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
            if walletViewModel.wallets.isEmpty {
                walletViewModel.loadWallets()
            }
        }
    }

    // MARK: - Wallet QR Code Card
    private func walletQRCodeCard(wallet: WalletAddress) -> some View {
        VStack(spacing: 14) {
            // Header with chain badge
            HStack {
                Text("收款地址")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                Spacer()
                ChainBadge(chain: wallet.chain)
            }

            // QR Code
            if let qrImage = generateQRCode(from: wallet.token) {
                VStack(spacing: 12) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(12)

                    Text("客户扫码向此地址转账 USDT")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
            }

            // Wallet Address Display
            HStack {
                Text(wallet.token)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Button(action: {
                    UIPasteboard.general.string = wallet.token
                    showCopiedAlert = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showCopiedAlert = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: showCopiedAlert ? "checkmark.circle.fill" : "doc.on.doc")
                        Text(showCopiedAlert ? "已复制" : "复制")
                            .font(.caption2)
                    }
                    .foregroundColor(showCopiedAlert ? .statusSuccess : .gold)
                    .font(.system(size: 14))
                }
            }
            .padding(10)
            .background(Color.bgInput)
            .cornerRadius(8)

            // Save QR Code Button
            if let qrImage = generateQRCode(from: wallet.token) {
                Button(action: {
                    UIImageWriteToSavedPhotosAlbum(qrImage, nil, nil, nil)
                    showSavedAlert = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        showSavedAlert = false
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: showSavedAlert ? "checkmark.circle.fill" : "square.and.arrow.down")
                        Text(showSavedAlert ? "已保存" : "保存二维码到相册")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.accentText)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.gold)
                    .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(Color.bgCard)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gold.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - QR Code Generator
    private func generateQRCode(from string: String) -> UIImage? {
        let data = string.data(using: .utf8)
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        guard let ciImage = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = ciImage.transformed(by: transform)
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
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
