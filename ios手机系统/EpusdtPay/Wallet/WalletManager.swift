//
//  WalletManager.swift
//  EpusdtPay
//
//  统一钱包管理类
//  根据选择的区块链网络自动路由到对应的 Provider:
//    - EVM 链 (ETH/BSC/Polygon) -> WalletConnectProvider
//    - TRON 链 -> TronLinkProvider
//  对外暴露统一的连接/断开/发送交易接口
//

import Foundation
import Combine
import SwiftUI

// MARK: - WalletManager

/// 统一钱包管理类，作为 SwiftUI 的 EnvironmentObject 使用
@MainActor
final class WalletManager: ObservableObject {

    // MARK: - Published 属性 (UI 绑定)

    /// 钱包是否已连接
    @Published var isConnected: Bool = false

    /// 当前连接的钱包账户地址
    @Published var currentAccount: String?

    /// 当前选择的区块链网络
    @Published var currentNetwork: BlockchainNetwork = .ethereum

    /// 当前钱包会话详情
    @Published var currentSession: WalletSession?

    /// 连接状态 (用于 UI 展示不同阶段)
    @Published var connectionState: WalletConnectionState = .disconnected

    /// WalletConnect 配对 URI (用于 QR 码展示)
    @Published var walletConnectURI: String?

    /// 正在加载标识
    @Published var isLoading: Bool = false

    /// 错误消息
    @Published var errorMessage: String?

    /// 最近一次交易的哈希
    @Published var lastTransactionHash: String?

    /// 交易处理中标识
    @Published var isTransactionPending: Bool = false

    // MARK: - 私有属性

    /// WalletConnect 提供者 (EVM 链)
    private let walletConnectProvider = WalletConnectProvider.shared

    /// TronLink 提供者 (TRON 链)
    private let tronLinkProvider = TronLinkProvider.shared

    /// 当前活跃的提供者
    private var activeProvider: WalletConnectionProvider?

    /// Combine 订阅集合
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 单例

    static let shared = WalletManager()

    // MARK: - 初始化

    init() {
        setupStateObservers()
        restorePreviousSession()
    }

    // MARK: - 状态监听

    /// 设置 Provider 状态变化的监听
    private func setupStateObservers() {
        // 监听 WalletConnect 状态变化
        walletConnectProvider.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                // 只在 WalletConnect 是活跃提供者时处理
                if self.activeProvider === self.walletConnectProvider {
                    self.handleStateChange(state)
                }
            }
            .store(in: &cancellables)

        // 监听 TronLink 状态变化
        tronLinkProvider.connectionStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                if self.activeProvider === self.tronLinkProvider {
                    self.handleStateChange(state)
                }
            }
            .store(in: &cancellables)
    }

    /// 处理连接状态变化
    private func handleStateChange(_ state: WalletConnectionState) {
        connectionState = state

        switch state {
        case .disconnected:
            isConnected = false
            currentAccount = nil
            currentSession = nil
            walletConnectURI = nil
            isLoading = false

        case .connecting:
            isLoading = true
            errorMessage = nil

        case .waitingForApproval(let uri):
            isLoading = false
            walletConnectURI = uri

        case .connected(let session):
            isConnected = true
            currentAccount = session.address
            currentSession = session
            currentNetwork = session.network
            walletConnectURI = nil
            isLoading = false
            errorMessage = nil

        case .error(let message):
            isLoading = false
            errorMessage = message
        }
    }

    // MARK: - 会话恢复

    /// 尝试恢复之前的会话
    private func restorePreviousSession() {
        Task {
            // 先尝试恢复 WalletConnect 会话
            if await walletConnectProvider.restoreSession() {
                activeProvider = walletConnectProvider
                return
            }

            // 再尝试恢复 TronLink 会话
            if await tronLinkProvider.restoreSession() {
                activeProvider = tronLinkProvider
                return
            }
        }
    }

    // MARK: - 网络选择

    /// 根据网络获取对应的 Provider
    private func provider(for network: BlockchainNetwork) -> WalletConnectionProvider {
        switch network {
        case .ethereum, .bsc, .polygon:
            return walletConnectProvider
        case .tron:
            return tronLinkProvider
        }
    }

    /// 切换区块链网络
    /// 如果当前已连接且新网络需要不同的 Provider，会先断开再重连
    func switchNetwork(_ network: BlockchainNetwork) async {
        let newProvider = provider(for: network)

        // 如果 Provider 不变且已连接，只需切换链
        if activeProvider === newProvider && isConnected {
            currentNetwork = network
            return
        }

        // Provider 变化，需要断开旧连接
        if isConnected {
            await disconnectWallet()
        }

        currentNetwork = network
    }

    // MARK: - 连接钱包

    /// 连接钱包 (统一入口)
    /// 根据当前选择的网络自动路由到对应的 Provider
    func connectWallet() async {
        await connectWallet(network: currentNetwork)
    }

    /// 连接钱包到指定网络
    func connectWallet(network: BlockchainNetwork) async {
        // 如果已连接到相同网络，跳过
        if isConnected && currentNetwork == network {
            return
        }

        // 如果已连接到不同网络，先断开
        if isConnected {
            await disconnectWallet()
        }

        currentNetwork = network
        let selectedProvider = provider(for: network)
        activeProvider = selectedProvider

        errorMessage = nil
        isLoading = true

        do {
            try await selectedProvider.connect(network: network)
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    /// 通过指定钱包 App 连接 (用于钱包选择列表)
    func connectWithWallet(_ walletInfo: WalletAppInfo, network: BlockchainNetwork) async {
        currentNetwork = network

        switch walletInfo.providerType {
        case .walletConnect:
            activeProvider = walletConnectProvider
            do {
                try await walletConnectProvider.connect(network: network)

                // 等待 URI 生成后，打开指定钱包
                if let uri = walletConnectURI {
                    walletConnectProvider.openWalletWithURI(walletInfo, uri: uri)
                }
            } catch {
                errorMessage = error.localizedDescription
            }

        case .tronLink:
            activeProvider = tronLinkProvider
            do {
                try await tronLinkProvider.connect(network: .tron)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - 断开钱包

    /// 断开当前钱包连接
    func disconnectWallet() async {
        guard let provider = activeProvider else { return }

        do {
            try await provider.disconnect()
        } catch {
            print("[WalletManager] 断开连接出错: \(error.localizedDescription)")
        }

        // 重置所有状态
        activeProvider = nil
        isConnected = false
        currentAccount = nil
        currentSession = nil
        walletConnectURI = nil
        errorMessage = nil
        lastTransactionHash = nil
        connectionState = .disconnected
    }

    // MARK: - 发送交易

    /// 发送 USDT 转账交易 (统一入口)
    /// - Parameters:
    ///   - toAddress: 收款地址
    ///   - amount: USDT 数量
    /// - Returns: 交易结果
    @discardableResult
    func sendUSDTTransfer(toAddress: String, amount: Decimal) async -> TransactionResult {
        guard let provider = activeProvider else {
            errorMessage = "钱包未连接"
            return .failed(WalletProviderError.notConnected)
        }

        let request = TransactionRequest(
            toAddress: toAddress,
            amount: amount,
            network: currentNetwork
        )

        isTransactionPending = true
        errorMessage = nil
        lastTransactionHash = nil

        do {
            let result = try await provider.sendTransaction(request)

            await MainActor.run {
                isTransactionPending = false

                switch result {
                case .success(let txHash):
                    lastTransactionHash = txHash
                    print("[WalletManager] 交易成功: \(txHash)")

                case .rejected:
                    errorMessage = "交易已被用户取消"

                case .failed(let error):
                    errorMessage = error.localizedDescription
                }
            }

            return result

        } catch {
            isTransactionPending = false
            errorMessage = error.localizedDescription
            return .failed(error)
        }
    }

    /// 发送 ERC20/TRC20 approve 授权 (统一入口)
    /// - Parameters:
    ///   - spenderAddress: 被授权地址
    ///   - amount: 授权 USDT 数量
    /// - Returns: 交易结果
    @discardableResult
    func approveUSDT(spenderAddress: String, amount: Decimal) async -> TransactionResult {
        guard let provider = activeProvider else {
            errorMessage = "钱包未连接"
            return .failed(WalletProviderError.notConnected)
        }

        let request = ApproveRequest(
            spenderAddress: spenderAddress,
            amount: amount,
            network: currentNetwork
        )

        isTransactionPending = true
        errorMessage = nil

        do {
            let result = try await provider.approve(request)

            await MainActor.run {
                isTransactionPending = false

                switch result {
                case .success(let txHash):
                    lastTransactionHash = txHash

                case .rejected:
                    errorMessage = "授权已被用户取消"

                case .failed(let error):
                    errorMessage = error.localizedDescription
                }
            }

            return result

        } catch {
            isTransactionPending = false
            errorMessage = error.localizedDescription
            return .failed(error)
        }
    }

    // MARK: - Deep Link 回调处理

    /// 处理从钱包 App 返回的 Deep Link 回调
    /// 应在 AppDelegate / SceneDelegate 的 openURL 中调用
    func handleDeepLinkCallback(url: URL) {
        // 根据 URL 路由到对应的 Provider
        if let host = URLComponents(url: url, resolvingAgainstBaseURL: false)?.host {
            switch host {
            case "tronlink":
                tronLinkProvider.handleDeepLinkCallback(url: url)
            case "wc", "walletconnect":
                walletConnectProvider.handleDeepLinkCallback(url: url)
            default:
                // 尝试两个 Provider 都处理
                walletConnectProvider.handleDeepLinkCallback(url: url)
                tronLinkProvider.handleDeepLinkCallback(url: url)
            }
        }
    }

    // MARK: - 工具方法

    /// 获取当前网络可用的钱包列表
    var availableWallets: [WalletAppInfo] {
        SupportedWallets.wallets(for: currentNetwork)
    }

    /// 获取所有支持的钱包列表
    var allSupportedWallets: [WalletAppInfo] {
        SupportedWallets.all
    }

    /// 检查指定钱包是否已安装
    func isWalletInstalled(_ wallet: WalletAppInfo) -> Bool {
        switch wallet.providerType {
        case .walletConnect:
            return walletConnectProvider.isWalletInstalled(wallet)
        case .tronLink:
            return tronLinkProvider.isTronLinkInstalled
        }
    }

    /// 获取交易在区块浏览器中的 URL
    func explorerURL(for txHash: String) -> URL? {
        currentNetwork.explorerURL(txHash: txHash)
    }

    /// 清除错误消息
    func clearError() {
        errorMessage = nil
    }

    /// 重置连接状态 (取消当前连接尝试)
    func cancelConnection() async {
        if case .connecting = connectionState {
            await disconnectWallet()
        } else if case .waitingForApproval = connectionState {
            await disconnectWallet()
        }
    }
}

// MARK: - 便利扩展

extension WalletManager {

    /// 连接状态文本描述
    var connectionStatusText: String {
        switch connectionState {
        case .disconnected:
            return "未连接"
        case .connecting:
            return "正在连接..."
        case .waitingForApproval:
            return "等待钱包确认..."
        case .connected(let session):
            return "已连接: \(session.shortAddress)"
        case .error(let message):
            return "错误: \(message)"
        }
    }

    /// 当前网络名称
    var networkName: String {
        currentNetwork.rawValue
    }

    /// 当前账户缩短地址
    var shortAccountAddress: String? {
        currentSession?.shortAddress
    }
}
