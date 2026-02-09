//
//  WalletConnectionView.swift
//  EpusdtPay
//
//  钱包连接页面 (SwiftUI)
//  包含: 链选择器、钱包列表、QR 码展示、连接状态
//  设计风格: 深色主题 (背景 #0f1218, 卡片 #171c25, 金色强调 #d4af37)
//

import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - 钱包连接主页面

struct WalletConnectionView: View {
    @ObservedObject var walletManager: WalletManager
    @Environment(\.dismiss) private var dismiss

    /// 当前选中的网络索引 (用于 Picker)
    @State private var selectedNetworkIndex: Int = 0

    /// 是否显示 QR 码弹窗
    @State private var showQRCode: Bool = false

    /// 是否显示断开确认弹窗
    @State private var showDisconnectAlert: Bool = false

    /// 所有支持的网络
    private let networks = BlockchainNetwork.allCases

    var body: some View {
        NavigationView {
            ZStack {
                // 背景渐变
                backgroundGradient
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        // 连接状态卡片
                        connectionStatusCard

                        // 链选择器
                        if !walletManager.isConnected {
                            chainSelector
                        }

                        // 内容区域 (根据连接状态切换)
                        if walletManager.isConnected {
                            connectedContent
                        } else if case .waitingForApproval(let uri) = walletManager.connectionState {
                            waitingForApprovalContent(uri: uri)
                        } else {
                            walletSelectionContent
                        }

                        // 错误提示
                        if let error = walletManager.errorMessage {
                            errorBanner(message: error)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("连接钱包")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: 0xd4af37))
                }

                if walletManager.isConnected {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("断开") {
                            showDisconnectAlert = true
                        }
                        .foregroundColor(Color(hex: 0xe74c3c))
                    }
                }
            }
            .alert("断开钱包", isPresented: $showDisconnectAlert) {
                Button("取消", role: .cancel) {}
                Button("断开", role: .destructive) {
                    Task {
                        await walletManager.disconnectWallet()
                    }
                }
            } message: {
                Text("确定要断开当前钱包连接吗？")
            }
            .sheet(isPresented: $showQRCode) {
                if let uri = walletManager.walletConnectURI {
                    QRCodeSheet(uri: uri)
                }
            }
        }
    }

    // MARK: - 背景渐变

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(hex: 0x0f1218),
                Color(hex: 0x171c25)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - 连接状态卡片

    private var connectionStatusCard: some View {
        VStack(spacing: 12) {
            // 状态图标
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 64, height: 64)

                Image(systemName: statusIcon)
                    .font(.system(size: 28))
                    .foregroundColor(statusColor)
            }

            // 状态文本
            Text(walletManager.connectionStatusText)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(hex: 0xe6e6e6))

            // 已连接时显示详细信息
            if let session = walletManager.currentSession {
                VStack(spacing: 6) {
                    // 地址
                    HStack(spacing: 6) {
                        Image(systemName: walletManager.currentNetwork.iconName)
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: walletManager.currentNetwork.brandColorHex))

                        Text(session.shortAddress)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(Color(hex: 0x999999))

                        Button(action: {
                            UIPasteboard.general.string = session.address
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: 0x999999))
                        }
                    }

                    // 网络 & 钱包名称
                    HStack(spacing: 8) {
                        networkBadge(session.network)

                        Text(session.walletName)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: 0x999999))
                    }
                }
            }

            // 加载指示器
            if walletManager.isLoading {
                ProgressView()
                    .tint(Color(hex: 0xd4af37))
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(hex: 0x171c25))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(statusColor.opacity(0.3), lineWidth: 1)
        )
    }

    /// 状态对应的颜色
    private var statusColor: Color {
        switch walletManager.connectionState {
        case .disconnected: return Color(hex: 0x999999)
        case .connecting, .waitingForApproval: return Color(hex: 0xd4af37)
        case .connected: return Color(hex: 0x2ecc71)
        case .error: return Color(hex: 0xe74c3c)
        }
    }

    /// 状态对应的图标
    private var statusIcon: String {
        switch walletManager.connectionState {
        case .disconnected: return "link.badge.plus"
        case .connecting: return "antenna.radiowaves.left.and.right"
        case .waitingForApproval: return "qrcode"
        case .connected: return "checkmark.shield.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    // MARK: - 链选择器

    private var chainSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择网络")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: 0x999999))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(networks) { network in
                        chainButton(network)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 单个链选择按钮
    private func chainButton(_ network: BlockchainNetwork) -> some View {
        let isSelected = walletManager.currentNetwork == network

        return Button(action: {
            Task {
                await walletManager.switchNetwork(network)
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: network.iconName)
                    .font(.system(size: 16))
                    .foregroundColor(
                        isSelected
                            ? Color(hex: 0x0f1218)
                            : Color(hex: network.brandColorHex)
                    )

                Text(network.rawValue)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(
                        isSelected
                            ? Color(hex: 0x0f1218)
                            : Color(hex: 0xe6e6e6)
                    )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                isSelected
                    ? Color(hex: 0xd4af37)
                    : Color(hex: 0x171c25)
            )
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected
                            ? Color.clear
                            : Color(hex: 0x2a3444),
                        lineWidth: 1
                    )
            )
        }
    }

    // MARK: - 钱包选择列表

    private var walletSelectionContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择钱包")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: 0x999999))

            // 根据当前网络获取可用钱包
            let wallets = SupportedWallets.wallets(for: walletManager.currentNetwork)

            ForEach(wallets) { wallet in
                walletRow(wallet)
            }

            // QR 码扫描选项 (仅 EVM 链)
            if walletManager.currentNetwork.isEVM {
                qrCodeScanButton
            }

            // TronLink 未安装提示
            if walletManager.currentNetwork == .tron && !TronLinkProvider.shared.isTronLinkInstalled {
                tronLinkInstallBanner
            }
        }
    }

    /// 钱包行
    private func walletRow(_ wallet: WalletAppInfo) -> some View {
        Button(action: {
            Task {
                await walletManager.connectWithWallet(wallet, network: walletManager.currentNetwork)
            }
        }) {
            HStack(spacing: 14) {
                // 钱包图标
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: 0x222a36))
                        .frame(width: 44, height: 44)

                    Image(systemName: wallet.iconName)
                        .font(.system(size: 22))
                        .foregroundColor(Color(hex: 0xd4af37))
                }

                // 钱包名称 & 支持链
                VStack(alignment: .leading, spacing: 4) {
                    Text(wallet.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: 0xe6e6e6))

                    HStack(spacing: 4) {
                        ForEach(wallet.supportedNetworks.prefix(3)) { network in
                            Text(network.rawValue)
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: 0x999999))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: 0x222a36))
                                .cornerRadius(4)
                        }
                    }
                }

                Spacer()

                // 安装状态
                if walletManager.isWalletInstalled(wallet) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: 0x999999))
                } else {
                    Text("未安装")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: 0x999999))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: 0x222a36))
                        .cornerRadius(4)
                }
            }
            .padding(14)
            .background(Color(hex: 0x171c25))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(hex: 0x2a3444), lineWidth: 1)
            )
        }
    }

    /// QR 码扫描按钮 (通用 WalletConnect)
    private var qrCodeScanButton: some View {
        Button(action: {
            Task {
                await walletManager.connectWallet()
                if walletManager.walletConnectURI != nil {
                    showQRCode = true
                }
            }
        }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: 0x222a36))
                        .frame(width: 44, height: 44)

                    Image(systemName: "qrcode")
                        .font(.system(size: 22))
                        .foregroundColor(Color(hex: 0xd4af37))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("扫描 QR 码")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: 0xe6e6e6))

                    Text("使用任意 WalletConnect 兼容钱包扫码连接")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: 0x999999))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: 0x999999))
            }
            .padding(14)
            .background(Color(hex: 0x171c25))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(hex: 0x2a3444), lineWidth: 1)
            )
        }
    }

    /// TronLink 安装引导
    private var tronLinkInstallBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 20))
                .foregroundColor(Color(hex: 0xf39c12))

            VStack(alignment: .leading, spacing: 4) {
                Text("TronLink 未安装")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: 0xe6e6e6))

                Text("TRON 链交易需要 TronLink 钱包")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: 0x999999))
            }

            Spacer()

            Button("安装") {
                TronLinkProvider.shared.openAppStore()
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(Color(hex: 0x0f1218))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(hex: 0xf39c12))
            .cornerRadius(6)
        }
        .padding(14)
        .background(Color(hex: 0xf39c12).opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(hex: 0xf39c12).opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - 等待确认内容

    private func waitingForApprovalContent(uri: String) -> some View {
        VStack(spacing: 20) {
            // QR 码
            qrCodeImage(from: uri)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 220)
                .padding(16)
                .background(Color.white)
                .cornerRadius(12)

            Text("请使用钱包扫描 QR 码")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(hex: 0xe6e6e6))

            Text("或点击下方按钮在已安装的钱包中打开")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: 0x999999))
                .multilineTextAlignment(.center)

            // 快速打开钱包按钮
            let evmWallets = SupportedWallets.evmWallets
            HStack(spacing: 12) {
                ForEach(evmWallets) { wallet in
                    Button(action: {
                        WalletConnectProvider.shared.openWalletWithURI(wallet, uri: uri)
                    }) {
                        VStack(spacing: 6) {
                            Image(systemName: wallet.iconName)
                                .font(.system(size: 24))
                                .foregroundColor(Color(hex: 0xd4af37))

                            Text(wallet.name)
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: 0x999999))
                                .lineLimit(1)
                        }
                        .frame(width: 70, height: 60)
                        .background(Color(hex: 0x171c25))
                        .cornerRadius(8)
                    }
                }
            }

            // 复制 URI 按钮
            Button(action: {
                UIPasteboard.general.string = uri
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14))
                    Text("复制连接链接")
                        .font(.system(size: 14))
                }
                .foregroundColor(Color(hex: 0xd4af37))
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .background(Color(hex: 0xd4af37).opacity(0.1))
                .cornerRadius(8)
            }

            // 取消按钮
            Button("取消连接") {
                Task {
                    await walletManager.cancelConnection()
                }
            }
            .font(.system(size: 14))
            .foregroundColor(Color(hex: 0xe74c3c))
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(hex: 0x171c25))
        .cornerRadius(12)
    }

    // MARK: - 已连接内容

    private var connectedContent: some View {
        VStack(spacing: 16) {
            // 钱包详情
            if let session = walletManager.currentSession {
                walletDetailCard(session)
            }

            // 最近交易
            if let txHash = walletManager.lastTransactionHash {
                lastTransactionCard(txHash: txHash)
            }

            // 操作按钮
            actionButtons
        }
    }

    /// 钱包详情卡片
    private func walletDetailCard(_ session: WalletSession) -> some View {
        VStack(spacing: 14) {
            HStack {
                Text("钱包详情")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: 0x999999))
                Spacer()
            }

            // 地址行
            detailRow(label: "地址", value: session.address, monospaced: true) {
                UIPasteboard.general.string = session.address
            }

            Divider()
                .background(Color(hex: 0x2a3444))

            // 网络行
            detailRow(label: "网络", value: session.network.rawValue)

            Divider()
                .background(Color(hex: 0x2a3444))

            // 钱包行
            detailRow(label: "钱包", value: session.walletName)

            Divider()
                .background(Color(hex: 0x2a3444))

            // 连接时间
            detailRow(
                label: "连接时间",
                value: formatDate(session.connectedAt)
            )
        }
        .padding(16)
        .background(Color(hex: 0x171c25))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(hex: 0x2a3444), lineWidth: 1)
        )
    }

    /// 详情行
    private func detailRow(
        label: String,
        value: String,
        monospaced: Bool = false,
        copyAction: (() -> Void)? = nil
    ) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(Color(hex: 0x999999))
                .frame(width: 70, alignment: .leading)

            if monospaced {
                Text(value)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color(hex: 0xe6e6e6))
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Text(value)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: 0xe6e6e6))
            }

            Spacer()

            if let action = copyAction {
                Button(action: action) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: 0x999999))
                }
            }
        }
    }

    /// 最近交易卡片
    private func lastTransactionCard(txHash: String) -> some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color(hex: 0x2ecc71))

                Text("交易已提交")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: 0x2ecc71))

                Spacer()
            }

            HStack {
                Text(txHash)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color(hex: 0x999999))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                // 复制
                Button(action: {
                    UIPasteboard.general.string = txHash
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: 0x999999))
                }

                // 在浏览器中查看
                if let url = walletManager.explorerURL(for: txHash) {
                    Link(destination: url) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: 0xd4af37))
                    }
                }
            }
        }
        .padding(14)
        .background(Color(hex: 0x2ecc71).opacity(0.08))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(hex: 0x2ecc71).opacity(0.2), lineWidth: 1)
        )
    }

    /// 操作按钮
    private var actionButtons: some View {
        VStack(spacing: 10) {
            // 切换网络按钮
            Button(action: {
                Task {
                    await walletManager.disconnectWallet()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 16))
                    Text("切换网络 / 钱包")
                        .font(.system(size: 15, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(Color(hex: 0x171c25))
                .foregroundColor(Color(hex: 0xd4af37))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: 0xd4af37).opacity(0.3), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - 错误横幅

    private func errorBanner(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Color(hex: 0xe74c3c))

            Text(message)
                .font(.system(size: 13))
                .foregroundColor(Color(hex: 0xe74c3c))
                .lineLimit(3)

            Spacer()

            Button(action: {
                walletManager.clearError()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: 0x999999))
            }
        }
        .padding(12)
        .background(Color(hex: 0xe74c3c).opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - 网络标签

    private func networkBadge(_ network: BlockchainNetwork) -> some View {
        HStack(spacing: 4) {
            Image(systemName: network.iconName)
                .font(.system(size: 10))
            Text(network.rawValue)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(Color(hex: network.brandColorHex))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(hex: network.brandColorHex).opacity(0.12))
        .cornerRadius(6)
    }

    // MARK: - 工具方法

    /// 生成 QR 码图片
    private func qrCodeImage(from string: String) -> Image {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let ciImage = filter.outputImage else {
            return Image(systemName: "qrcode")
        }

        // 放大 QR 码
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = ciImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return Image(systemName: "qrcode")
        }

        return Image(uiImage: UIImage(cgImage: cgImage))
    }

    /// 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

// MARK: - QR 码弹窗

/// QR 码全屏展示弹窗
struct QRCodeSheet: View {
    let uri: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(hex: 0x0f1218)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // 标题
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("扫描 QR 码")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(hex: 0xe6e6e6))

                        Text("使用 WalletConnect 兼容钱包扫描连接")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: 0x999999))
                    }

                    Spacer()

                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color(hex: 0x999999))
                    }
                }

                Spacer()

                // QR 码
                qrCodeImage(from: uri)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 260, height: 260)
                    .padding(20)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: Color(hex: 0xd4af37).opacity(0.2), radius: 20)

                Spacer()

                // 复制按钮
                Button(action: {
                    UIPasteboard.general.string = uri
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.on.doc")
                        Text("复制连接链接")
                    }
                    .font(.system(size: 15, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(Color(hex: 0xd4af37))
                    .foregroundColor(Color(hex: 0x0f1218))
                    .cornerRadius(8)
                }
            }
            .padding(24)
        }
    }

    /// 生成 QR 码
    private func qrCodeImage(from string: String) -> Image {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let ciImage = filter.outputImage else {
            return Image(systemName: "qrcode")
        }

        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = ciImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return Image(systemName: "qrcode")
        }

        return Image(uiImage: UIImage(cgImage: cgImage))
    }
}

// MARK: - Preview

#Preview {
    WalletConnectionView(walletManager: WalletManager())
        .preferredColorScheme(.dark)
}
