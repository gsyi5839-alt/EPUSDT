//
//  TronLinkProvider.swift
//  EpusdtPay
//
//  TronLink Deep Link 降级方案实现
//  当 TRON 链不支持 WalletConnect 时，通过 TronLink App 的 Deep Link 进行交互
//  支持 TRC20 USDT 转账和 TronLink 安装检测
//

import Foundation
import Combine
import UIKit

// MARK: - TronLink 配置

/// TronLink Deep Link 相关常量
struct TronLinkConfig {
    /// TronLink URL Scheme
    static let urlScheme = "tronlinkoutside://"

    /// TronLink App Store 链接
    static let appStoreURL = "https://apps.apple.com/app/tronlink/id1453530188"

    /// TronLink 回调 URL Scheme (需要在 Info.plist 中注册)
    static let callbackScheme = "epusdtpay"

    /// TRC20 USDT 合约地址
    static let usdtContract = "TR7NHqjeKQxGTCi8q282RJWC3SVrFoJypL"

    /// USDT 精度
    static let usdtDecimals = 6

    /// 交易确认轮询间隔 (秒)
    static let pollingInterval: TimeInterval = 3.0

    /// 交易确认最大等待时间 (秒)
    static let maxWaitTime: TimeInterval = 300
}

// MARK: - TronLink Provider

/// TronLink Deep Link 钱包提供者
/// 当用户选择 TRON 网络时，使用此提供者通过 Deep Link 与 TronLink App 交互
final class TronLinkProvider: WalletConnectionProvider {

    // MARK: - 属性

    /// 连接状态发布者
    var connectionStatePublisher: AnyPublisher<WalletConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }

    /// 当前连接状态
    var currentState: WalletConnectionState {
        connectionStateSubject.value
    }

    /// 仅支持 TRON 网络
    let supportedNetworks: [BlockchainNetwork] = [.tron]

    // MARK: - 私有属性

    /// 状态主题
    private let connectionStateSubject = CurrentValueSubject<WalletConnectionState, Never>(.disconnected)

    /// 当前活跃会话
    private var activeSession: WalletSession?

    /// 会话持久化 Key
    private let sessionStorageKey = "com.epusdt.tronlink.session"

    /// 待处理的交易回调
    private var pendingTransactionContinuation: CheckedContinuation<TransactionResult, Error>?

    /// 交易超时任务
    private var transactionTimeoutTask: Task<Void, Never>?

    /// Combine 订阅集合
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 单例

    static let shared = TronLinkProvider()

    private init() {}

    // MARK: - TronLink 检测

    /// 检查 TronLink App 是否已安装
    var isTronLinkInstalled: Bool {
        guard let url = URL(string: TronLinkConfig.urlScheme) else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    // MARK: - 连接

    /// 发起 TronLink 连接
    /// TronLink 的连接方式是通过 Deep Link 唤起 App，用户在 TronLink 中授权后返回
    func connect(network: BlockchainNetwork) async throws {
        // 验证网络
        guard network == .tron else {
            throw WalletProviderError.unsupportedNetwork
        }

        // 检查 TronLink 是否安装
        guard isTronLinkInstalled else {
            connectionStateSubject.send(.error("TronLink 未安装"))
            throw WalletProviderError.walletAppNotInstalled("TronLink")
        }

        connectionStateSubject.send(.connecting)

        // 构造 TronLink 授权连接 Deep Link
        let connectURL = buildConnectDeepLink()

        guard let url = URL(string: connectURL) else {
            connectionStateSubject.send(.error("无法构造连接 URL"))
            throw WalletProviderError.connectionFailed("无效的 Deep Link URL")
        }

        // 唤起 TronLink App
        let opened = await openURL(url)

        if !opened {
            connectionStateSubject.send(.error("无法打开 TronLink"))
            throw WalletProviderError.walletAppNotInstalled("TronLink")
        }

        // TronLink 会通过回调返回地址
        // 在 handleDeepLinkCallback 中处理
        connectionStateSubject.send(.waitingForApproval(uri: connectURL))

        print("[TronLink] 已唤起 TronLink App，等待用户授权...")
    }

    /// 构造 TronLink 连接授权 Deep Link
    private func buildConnectDeepLink() -> String {
        // TronLink Deep Link 格式:
        // tronlinkoutside://pull.activity?param={json_encoded_params}
        //
        // 参数结构:
        // {
        //   "url": "回调URL",
        //   "action": "authorization",
        //   "protocol": "TronLink",
        //   "version": "1.0",
        //   "dappName": "Epusdt Pay",
        //   "dappIcon": "https://epusdt.pay/icon.png"
        // }

        let params: [String: String] = [
            "url": "\(TronLinkConfig.callbackScheme)://tronlink/connect",
            "action": "authorization",
            "protocol": "TronLink",
            "version": "1.0",
            "dappName": "Epusdt Pay",
            "dappIcon": "https://epusdt.pay/icon.png"
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: params),
              let jsonString = String(data: jsonData, encoding: .utf8),
              let encodedParams = jsonString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return "\(TronLinkConfig.urlScheme)pull.activity"
        }

        return "\(TronLinkConfig.urlScheme)pull.activity?param=\(encodedParams)"
    }

    // MARK: - 发送交易

    /// 发送 TRC20 USDT 转账交易
    /// 通过 TronLink Deep Link 唤起钱包进行签名
    func sendTransaction(_ request: TransactionRequest) async throws -> TransactionResult {
        guard activeSession != nil else {
            throw WalletProviderError.notConnected
        }

        guard request.network == .tron else {
            throw WalletProviderError.unsupportedNetwork
        }

        // 验证目标地址格式 (TRON 地址以 T 开头，Base58 编码，34 字符)
        guard isValidTronAddress(request.toAddress) else {
            throw WalletProviderError.invalidAddress
        }

        // 构造 TRC20 转账 Deep Link
        let transferURL = buildTransferDeepLink(
            toAddress: request.toAddress,
            amount: request.amount,
            contractAddress: TronLinkConfig.usdtContract
        )

        guard let url = URL(string: transferURL) else {
            throw WalletProviderError.encodingError
        }

        // 使用 CheckedContinuation 等待 TronLink 回调
        return try await withCheckedThrowingContinuation { continuation in
            pendingTransactionContinuation = continuation

            // 启动超时计时器
            startTransactionTimeout()

            // 唤起 TronLink
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                UIApplication.shared.open(url) { success in
                    if !success {
                        self.cancelTransactionTimeout()
                        self.pendingTransactionContinuation = nil
                        continuation.resume(throwing: WalletProviderError.walletAppNotInstalled("TronLink"))
                    } else {
                        print("[TronLink] 已唤起转账页面，等待用户确认...")
                    }
                }
            }
        }
    }

    /// 构造 TRC20 转账 Deep Link
    private func buildTransferDeepLink(toAddress: String, amount: Decimal, contractAddress: String) -> String {
        // TronLink 转账 Deep Link 格式:
        // tronlinkoutside://pull.activity?param={json_encoded_params}
        //
        // 转账参数:
        // {
        //   "url": "回调URL",
        //   "action": "transfer",
        //   "protocol": "TronLink",
        //   "version": "1.0",
        //   "dappName": "Epusdt Pay",
        //   "toAddress": "收款地址",
        //   "amount": "转账金额(最小单位)",
        //   "tokenType": "trc20",
        //   "contractAddress": "USDT合约地址",
        //   "memo": "备注"
        // }

        // 转换为最小单位 (sun, 6位精度)
        let multiplier = Decimal(pow(10.0, Double(TronLinkConfig.usdtDecimals)))
        let amountInSun = NSDecimalNumber(decimal: amount * multiplier).int64Value

        let params: [String: Any] = [
            "url": "\(TronLinkConfig.callbackScheme)://tronlink/transfer",
            "action": "transfer",
            "protocol": "TronLink",
            "version": "1.0",
            "dappName": "Epusdt Pay",
            "toAddress": toAddress,
            "amount": "\(amountInSun)",
            "tokenType": "trc20",
            "contractAddress": contractAddress,
            "memo": "USDT Payment via Epusdt Pay"
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: params),
              let jsonString = String(data: jsonData, encoding: .utf8),
              let encodedParams = jsonString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return "\(TronLinkConfig.urlScheme)pull.activity"
        }

        return "\(TronLinkConfig.urlScheme)pull.activity?param=\(encodedParams)"
    }

    // MARK: - 授权 (Approve)

    /// 发送 TRC20 approve 授权
    /// TRON 链的 approve 同样通过 Deep Link 唤起 TronLink
    func approve(_ request: ApproveRequest) async throws -> TransactionResult {
        guard activeSession != nil else {
            throw WalletProviderError.notConnected
        }

        guard request.network == .tron else {
            throw WalletProviderError.unsupportedNetwork
        }

        // 构造 TRC20 approve Deep Link
        let approveURL = buildApproveDeepLink(
            spenderAddress: request.spenderAddress,
            amount: request.amount,
            contractAddress: TronLinkConfig.usdtContract
        )

        guard let url = URL(string: approveURL) else {
            throw WalletProviderError.encodingError
        }

        return try await withCheckedThrowingContinuation { continuation in
            pendingTransactionContinuation = continuation
            startTransactionTimeout()

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                UIApplication.shared.open(url) { success in
                    if !success {
                        self.cancelTransactionTimeout()
                        self.pendingTransactionContinuation = nil
                        continuation.resume(throwing: WalletProviderError.walletAppNotInstalled("TronLink"))
                    }
                }
            }
        }
    }

    /// 构造 TRC20 approve Deep Link
    private func buildApproveDeepLink(spenderAddress: String, amount: Decimal, contractAddress: String) -> String {
        let multiplier = Decimal(pow(10.0, Double(TronLinkConfig.usdtDecimals)))
        let amountInSun = NSDecimalNumber(decimal: amount * multiplier).int64Value

        let params: [String: Any] = [
            "url": "\(TronLinkConfig.callbackScheme)://tronlink/approve",
            "action": "approve",
            "protocol": "TronLink",
            "version": "1.0",
            "dappName": "Epusdt Pay",
            "spenderAddress": spenderAddress,
            "amount": "\(amountInSun)",
            "tokenType": "trc20",
            "contractAddress": contractAddress
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: params),
              let jsonString = String(data: jsonData, encoding: .utf8),
              let encodedParams = jsonString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return "\(TronLinkConfig.urlScheme)pull.activity"
        }

        return "\(TronLinkConfig.urlScheme)pull.activity?param=\(encodedParams)"
    }

    // MARK: - 断开连接

    /// 断开 TronLink 会话
    /// TronLink 没有持久会话概念，仅清除本地状态
    func disconnect() async throws {
        cancelTransactionTimeout()
        activeSession = nil
        clearStoredSession()
        connectionStateSubject.send(.disconnected)
        print("[TronLink] 已断开连接")
    }

    // MARK: - 会话恢复

    /// 尝试恢复 TronLink 会话
    func restoreSession() async -> Bool {
        guard let sessionData = UserDefaults.standard.data(forKey: sessionStorageKey),
              let session = try? JSONDecoder().decode(WalletSession.self, from: sessionData) else {
            return false
        }

        // TronLink 会话有效期设为 12 小时
        let maxSessionAge: TimeInterval = 12 * 60 * 60
        guard Date().timeIntervalSince(session.connectedAt) < maxSessionAge else {
            clearStoredSession()
            return false
        }

        // 确认 TronLink 仍然安装
        guard isTronLinkInstalled else {
            clearStoredSession()
            return false
        }

        activeSession = session
        connectionStateSubject.send(.connected(session))
        print("[TronLink] 会话恢复成功: \(session.shortAddress)")
        return true
    }

    // MARK: - Deep Link 回调处理

    /// 处理从 TronLink App 返回的 Deep Link 回调
    /// 在 SceneDelegate / AppDelegate 的 openURL 中调用
    func handleDeepLinkCallback(url: URL) {
        print("[TronLink] 收到回调: \(url.absoluteString)")

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host else {
            return
        }

        // 确保是 TronLink 的回调路径
        guard host == "tronlink" else { return }

        let path = components.path
        let queryItems = components.queryItems ?? []

        switch path {
        case "/connect":
            handleConnectCallback(queryItems: queryItems)
        case "/transfer", "/approve":
            handleTransactionCallback(queryItems: queryItems)
        default:
            print("[TronLink] 未知回调路径: \(path)")
        }
    }

    /// 处理连接授权回调
    private func handleConnectCallback(queryItems: [URLQueryItem]) {
        // TronLink 连接成功回调参数:
        // address: TRON 钱包地址
        // action: "authorization"
        // result: "success" | "fail"

        let resultValue = queryItems.first(where: { $0.name == "result" })?.value
        let address = queryItems.first(where: { $0.name == "address" })?.value

        guard resultValue == "success", let walletAddress = address else {
            let errorMsg = queryItems.first(where: { $0.name == "message" })?.value ?? "授权失败"
            connectionStateSubject.send(.error(errorMsg))
            return
        }

        // 验证地址格式
        guard isValidTronAddress(walletAddress) else {
            connectionStateSubject.send(.error("无效的 TRON 地址"))
            return
        }

        // 创建会话
        let session = WalletSession(
            id: UUID().uuidString,
            address: walletAddress,
            network: .tron,
            walletName: "TronLink",
            connectedAt: Date()
        )

        activeSession = session
        saveSession(session)
        connectionStateSubject.send(.connected(session))

        print("[TronLink] 连接成功: \(session.shortAddress)")
    }

    /// 处理交易/授权回调
    private func handleTransactionCallback(queryItems: [URLQueryItem]) {
        cancelTransactionTimeout()

        let resultValue = queryItems.first(where: { $0.name == "result" })?.value
        let txHash = queryItems.first(where: { $0.name == "txHash" })?.value
            ?? queryItems.first(where: { $0.name == "txid" })?.value

        guard let continuation = pendingTransactionContinuation else {
            print("[TronLink] 收到交易回调但无等待中的请求")
            return
        }

        pendingTransactionContinuation = nil

        switch resultValue {
        case "success":
            if let hash = txHash {
                continuation.resume(returning: .success(txHash: hash))
                print("[TronLink] 交易成功: \(hash)")
            } else {
                // TronLink 有时不立即返回 txHash
                continuation.resume(returning: .success(txHash: "pending"))
                print("[TronLink] 交易已提交，等待确认...")
            }

        case "fail":
            let errorMsg = queryItems.first(where: { $0.name == "message" })?.value ?? "交易失败"
            continuation.resume(returning: .failed(WalletProviderError.transactionFailed(errorMsg)))

        case "cancel", "rejected":
            continuation.resume(returning: .rejected)
            print("[TronLink] 用户取消了交易")

        default:
            continuation.resume(returning: .failed(WalletProviderError.transactionFailed("未知回调结果")))
        }
    }

    // MARK: - 辅助方法

    /// 验证 TRON 地址格式
    /// TRON 地址以 T 开头，Base58Check 编码，长度为 34 字符
    private func isValidTronAddress(_ address: String) -> Bool {
        guard address.count == 34, address.hasPrefix("T") else {
            return false
        }

        // Base58 字符集验证
        let base58Chars = CharacterSet(charactersIn: "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
        return address.unicodeScalars.allSatisfy { base58Chars.contains($0) }
    }

    /// 异步打开 URL
    @MainActor
    private func openURL(_ url: URL) async -> Bool {
        guard UIApplication.shared.canOpenURL(url) else { return false }
        return await withCheckedContinuation { continuation in
            UIApplication.shared.open(url) { success in
                continuation.resume(returning: success)
            }
        }
    }

    // MARK: - 会话持久化

    /// 保存会话到本地存储
    private func saveSession(_ session: WalletSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        UserDefaults.standard.set(data, forKey: sessionStorageKey)
    }

    /// 清除存储的会话
    private func clearStoredSession() {
        UserDefaults.standard.removeObject(forKey: sessionStorageKey)
    }

    // MARK: - 超时管理

    /// 启动交易超时计时器
    private func startTransactionTimeout() {
        cancelTransactionTimeout()
        transactionTimeoutTask = Task { [weak self] in
            guard let self = self else { return }
            try? await Task.sleep(nanoseconds: UInt64(TronLinkConfig.maxWaitTime * 1_000_000_000))

            guard !Task.isCancelled else { return }

            if let continuation = self.pendingTransactionContinuation {
                self.pendingTransactionContinuation = nil
                continuation.resume(throwing: WalletProviderError.timeout)
                print("[TronLink] 交易等待超时")
            }
        }
    }

    /// 取消超时计时器
    private func cancelTransactionTimeout() {
        transactionTimeoutTask?.cancel()
        transactionTimeoutTask = nil
    }

    // MARK: - 引导安装

    /// 引导用户前往 App Store 安装 TronLink
    func openAppStore() {
        guard let url = URL(string: TronLinkConfig.appStoreURL) else { return }
        DispatchQueue.main.async {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - 模拟连接 (开发调试用)

    #if DEBUG
    /// 模拟 TronLink 连接成功
    func simulateConnection() {
        let mockAddress = "TN7oMgKp9K1rze4nHYdYzg1fFtoFkPDS3V"

        let session = WalletSession(
            id: UUID().uuidString,
            address: mockAddress,
            network: .tron,
            walletName: "TronLink",
            connectedAt: Date()
        )

        activeSession = session
        saveSession(session)
        connectionStateSubject.send(.connected(session))
    }

    /// 模拟交易回调
    func simulateTransactionCallback(success: Bool) {
        guard let continuation = pendingTransactionContinuation else { return }
        pendingTransactionContinuation = nil
        cancelTransactionTimeout()

        if success {
            let mockHash = (0..<32).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
            continuation.resume(returning: .success(txHash: mockHash))
        } else {
            continuation.resume(returning: .rejected)
        }
    }
    #endif
}
