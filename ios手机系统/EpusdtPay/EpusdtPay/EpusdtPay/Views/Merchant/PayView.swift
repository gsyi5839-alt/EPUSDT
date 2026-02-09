//
//  PayView.swift
//  EpusdtPay
//
//  Authorization creation, deduction, and query
//

import SwiftUI

struct PayView: View {
    @EnvironmentObject var paymentVM: PaymentViewModel
    @EnvironmentObject var walletViewModel: WalletViewModel
    @State private var selectedSection = 1
    @State private var selectedChain = "tron"
    @State private var showCopiedAlert = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Section Picker
                    Picker("", selection: $selectedSection) {
                        Text("扣款").tag(1)
                        Text("查询").tag(2)
                        Text("收款码").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)

                    // Error/Success Messages
                    if let error = paymentVM.errorMessage {
                        ErrorBanner(message: error, onDismiss: { paymentVM.errorMessage = nil })
                            .padding(.horizontal, 16)
                    }
                    if let success = paymentVM.successMessage {
                        SuccessBanner(message: success)
                            .padding(.horizontal, 16)
                    }

                    // MARK: - Section Content
                    switch selectedSection {
                    case 1:
                        deductSection
                    case 2:
                        querySection
                    case 3:
                        qrCodeSection
                    default:
                        EmptyView()
                    }
                }
                .padding(.vertical, 16)
            }
            .navigationTitle("收款")
            .darkBackground()
        }
    }

    // MARK: - Deduct Section
    private var deductSection: some View {
        VStack(spacing: 16) {
            FormField(
                label: "密码凭证",
                placeholder: "输入客户密码",
                text: $paymentVM.deductPassword
            )

            FormField(
                label: "扣款金额 (CNY ¥)",
                placeholder: "输入金额",
                text: $paymentVM.deductAmountCny,
                keyboardType: .decimalPad
            )

            FormField(
                label: "消费内容",
                placeholder: "如: 酒水3瓶",
                text: $paymentVM.deductProductInfo
            )

            FormField(
                label: "操作员 ID (可选)",
                placeholder: "操作员",
                text: $paymentVM.deductOperatorId
            )

            GoldButton(
                title: "确认扣款",
                isLoading: paymentVM.isLoading,
                action: paymentVM.deductFromAuthorization
            )

            // Deduct Result Card
            if let result = paymentVM.deductResult {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("扣款提交成功")
                            .font(.headline)
                            .foregroundColor(.statusSuccess)
                        Spacer()
                        Button("重置") {
                            paymentVM.resetDeductForm()
                        }
                        .font(.caption)
                        .foregroundColor(.gold)
                    }

                    Divider().background(Color.textSecondary.opacity(0.3))

                    InfoRow(label: "扣款单号", value: result.deductNo, valueColor: .gold)
                    InfoRow(label: "扣款 CNY", value: String(format: "¥%.2f", result.amountCny), valueColor: .statusWarning)
                    InfoRow(label: "扣款 USDT", value: String(format: "%.4f", result.amountUsdt), valueColor: .gold)
                    InfoRow(label: "剩余额度", value: String(format: "%.4f USDT", result.remainingUsdt), valueColor: .statusSuccess)
                }
                .padding(14)
                .background(Color.bgCard)
                .cornerRadius(10)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Query Section
    private var querySection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                FormField(
                    label: "密码凭证",
                    placeholder: "输入密码查询",
                    text: $paymentVM.queryPassword
                )

                VStack {
                    Spacer()
                    Button(action: {
                        paymentVM.queryAuthInfo()
                    }) {
                        Text("查询")
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.gold)
                            .foregroundColor(Color.accentText)
                            .cornerRadius(8)
                    }
                }
                .frame(height: 62)
            }

            // Auth Info Card
            if let info = paymentVM.authInfo {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("授权信息")
                            .font(.headline)
                            .foregroundColor(.textPrimary)
                        Spacer()
                        StatusBadge(authStatus: info.status)
                    }

                    Divider().background(Color.textSecondary.opacity(0.3))

                    InfoRow(label: "授权号", value: info.authNo, valueColor: .gold)
                    InfoRow(label: "授权金额", value: String(format: "%.2f USDT", info.authorizedUsdt))
                    InfoRow(label: "已使用", value: String(format: "%.2f USDT", info.usedUsdt), valueColor: .statusWarning)
                    InfoRow(label: "剩余", value: String(format: "%.2f USDT", info.remainingUsdt), valueColor: .statusSuccess)
                    if let table = info.tableNo, !table.isEmpty {
                        InfoRow(label: "桌号", value: table)
                    }
                    if let name = info.customerName, !name.isEmpty {
                        InfoRow(label: "客户", value: name)
                    }
                    if let wallet = info.customerWallet, !wallet.isEmpty {
                        InfoRow(label: "客户钱包", value: wallet)
                    }

                    // Load history button
                    Button(action: { paymentVM.queryDeductionHistory() }) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("查看扣款记录")
                        }
                        .font(.caption)
                        .foregroundColor(.gold)
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(Color.gold.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
                .padding(14)
                .background(Color.bgCard)
                .cornerRadius(10)
            }

            // Deduction History
            if !paymentVM.deductionHistory.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("扣款记录")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.textPrimary)

                    ForEach(paymentVM.deductionHistory) { deduct in
                        DeductionRowView(deduction: deduct)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - QR Code Section
    private var qrCodeSection: some View {
        VStack(spacing: 16) {
            // Chain Selector
            ChainPicker(selected: $selectedChain)

            // 钱包列表加载状态
            if walletViewModel.isLoading {
                ProgressView("加载钱包...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .gold))
                    .padding(20)
            } else if filteredWallets.isEmpty {
                // 无可用钱包提示
                VStack(spacing: 12) {
                    Image(systemName: "wallet.pass")
                        .font(.system(size: 36))
                        .foregroundColor(.textSecondary)
                    Text("未找到 \(chainDisplayName) 链的钱包")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                    Text("请在「钱包」页面添加钱包地址")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(30)
                .background(Color.bgCard)
                .cornerRadius(12)
            } else {
                // Wallet Address Card
                VStack(spacing: 12) {
                    HStack {
                        Text("商家收款地址")
                            .font(.headline)
                            .foregroundColor(.textPrimary)
                        Spacer()
                        if filteredWallets.count > 1 {
                            Text("\(filteredWallets.count) 个钱包")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // 展示每个钱包地址及其二维码
                    ForEach(filteredWallets) { wallet in
                        walletQRCodeCard(wallet: wallet)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .onAppear {
            if walletViewModel.wallets.isEmpty {
                walletViewModel.loadWallets()
            }
        }
        .onChange(of: selectedChain) {
            // 切换链时刷新
        }
    }

    /// 单个钱包的二维码卡片
    private func walletQRCodeCard(wallet: WalletAddress) -> some View {
        VStack(spacing: 12) {
            // Wallet Address Display
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("钱包地址")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    Spacer()
                    ChainBadge(chain: wallet.chain ?? selectedChain)
                }

                HStack {
                    Text(wallet.token)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.textPrimary)
                        .lineLimit(2)
                        .truncationMode(.middle)

                    Spacer()

                    Button(action: {
                        UIPasteboard.general.string = wallet.token
                        showCopiedAlert = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showCopiedAlert = false
                        }
                    }) {
                        Image(systemName: showCopiedAlert ? "checkmark.circle.fill" : "doc.on.doc")
                            .foregroundColor(showCopiedAlert ? .statusSuccess : .gold)
                            .font(.system(size: 18))
                    }
                }
            }
            .padding(12)
            .background(Color.bgInput)
            .cornerRadius(8)

            // QR Code Display
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

                    // Save QR Code Button
                    Button(action: {
                        UIImageWriteToSavedPhotosAlbum(qrImage, nil, nil, nil)
                        paymentVM.successMessage = "二维码已保存到相册"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            paymentVM.successMessage = nil
                        }
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("保存二维码")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.accentText)
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color.gold)
                        .cornerRadius(8)
                    }
                }
                .padding(.top, 8)
            }

            // Info Text
            Text("客户可扫描此二维码向您的钱包地址转账USDT")
                .font(.caption)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .padding(16)
        .background(Color.bgCard)
        .cornerRadius(12)
    }

    // MARK: - Helper Properties

    /// 按选中链过滤的钱包列表
    private var filteredWallets: [WalletAddress] {
        let chain = selectedChain.uppercased()
        return walletViewModel.wallets.filter { wallet in
            guard wallet.isEnabled else { return false }
            let walletChain = (wallet.chain ?? "").uppercased()
            // 匹配链名
            if chain == "ETH" || chain == "EVM" {
                return walletChain == "ETH" || walletChain == "EVM"
            }
            return walletChain == chain
        }
    }

    /// 当前选中链的显示名称
    private var chainDisplayName: String {
        switch selectedChain.lowercased() {
        case "tron": return "TRON"
        case "bsc": return "BSC"
        case "eth", "evm": return "ETH"
        case "polygon": return "Polygon"
        default: return selectedChain.uppercased()
        }
    }

    // MARK: - Helper Methods

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
