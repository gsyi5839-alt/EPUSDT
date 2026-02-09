//
//  WalletConnectProvider.swift
//  EpusdtPay
//
//  WalletConnect v2 协议实现
//  支持 EVM 兼容链 (Ethereum / BSC / Polygon) 上的 USDT 转账和授权
//  依赖: WalletConnectSwift SDK (通过 SPM 集成)
//

import Foundation
import Combine
import UIKit

// MARK: - WalletConnect 配置

/// WalletConnect v2 项目配置
struct WalletConnectConfig {
    /// WalletConnect Cloud 项目 ID (需在 https://cloud.walletconnect.com 注册)
    static let projectId = "YOUR_WALLETCONNECT_PROJECT_ID"

    /// 应用元数据
    static let metadata = AppMetadata(
        name: "Epusdt Pay",
        description: "加密货币 USDT 支付系统",
        url: "https://epusdt.pay",
        icons: ["https://epusdt.pay/icon.png"],
        redirect: AppMetadata.Redirect(
            native: "epusdtpay://",
            universal: nil
        )
    )
}

/// 应用元数据结构 (符合 WalletConnect v2 规范)
struct AppMetadata: Codable {
    let name: String
    let description: String
    let url: String
    let icons: [String]
    let redirect: Redirect?

    struct Redirect: Codable {
        let native: String?
        let universal: String?
    }
}

// MARK: - WalletConnect Provider

/// WalletConnect v2 钱包连接提供者
/// 负责通过 WalletConnect 协议与 EVM 兼容链上的钱包交互
final class WalletConnectProvider: WalletConnectionProvider {

    // MARK: - 属性

    /// 连接状态发布者
    var connectionStatePublisher: AnyPublisher<WalletConnectionState, Never> {
        connectionStateSubject.eraseToAnyPublisher()
    }

    /// 当前连接状态
    var currentState: WalletConnectionState {
        connectionStateSubject.value
    }

    /// 支持的网络 (仅 EVM 兼容链)
    let supportedNetworks: [BlockchainNetwork] = BlockchainNetwork.evmChains

    // MARK: - 私有属性

    /// 状态主题
    private let connectionStateSubject = CurrentValueSubject<WalletConnectionState, Never>(.disconnected)

    /// 当前活跃会话
    private var activeSession: WalletSession?

    /// 当前选择的网络
    private var selectedNetwork: BlockchainNetwork?

    /// 配对 URI (用于 QR 码 / Deep Link)
    private var pairingURI: String?

    /// 会话持久化 Key
    private let sessionStorageKey = "com.epusdt.walletconnect.session"

    /// 超时计时器
    private var connectionTimeoutTask: Task<Void, Never>?

    /// 连接超时时间 (秒)
    private let connectionTimeout: TimeInterval = 120

    /// Combine 订阅集合
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 单例

    static let shared = WalletConnectProvider()

    private init() {
        setupWalletConnectClient()
    }

    // MARK: - SDK 初始化

    /// 配置 WalletConnect v2 客户端
    private func setupWalletConnectClient() {
        // ----------------------------------------------------------------
        // 实际集成时，此处初始化 WalletConnect Swift SDK:
        //
        //   import WalletConnectSign
        //   import WalletConnectPairing
        //
        //   let metadata = AppMetadata(
        //       name: WalletConnectConfig.metadata.name,
        //       description: WalletConnectConfig.metadata.description,
        //       url: WalletConnectConfig.metadata.url,
        //       icons: WalletConnectConfig.metadata.icons,
        //       redirect: .init(native: "epusdtpay://", universal: nil)
        //   )
        //
        //   Pair.configure(metadata: metadata)
        //   Networking.configure(
        //       groupIdentifier: "group.com.epusdt.pay",
        //       projectId: WalletConnectConfig.projectId,
        //       socketFactory: DefaultSocketFactory()
        //   )
        //
        //   // 监听会话事件
        //   Sign.instance.sessionSettlePublisher
        //       .receive(on: DispatchQueue.main)
        //       .sink { [weak self] session in
        //           self?.handleSessionSettled(session)
        //       }
        //       .store(in: &cancellables)
        //
        //   Sign.instance.sessionDeletePublisher
        //       .receive(on: DispatchQueue.main)
        //       .sink { [weak self] _ in
        //           self?.handleSessionDeleted()
        //       }
        //       .store(in: &cancellables)
        // ----------------------------------------------------------------

        print("[WalletConnect] SDK 初始化完成, projectId: \(WalletConnectConfig.projectId)")
    }

    // MARK: - 连接

    /// 发起 WalletConnect 连接
    /// 1. 创建配对 URI
    /// 2. 进入等待审批状态 (展示 QR 码)
    /// 3. 等待钱包端确认
    func connect(network: BlockchainNetwork) async throws {
        // 校验网络是否为 EVM 链
        guard network.isEVM else {
            throw WalletProviderError.unsupportedNetwork
        }

        guard let chainId = network.chainId else {
            throw WalletProviderError.unsupportedNetwork
        }

        selectedNetwork = network
        connectionStateSubject.send(.connecting)

        do {
            // 生成配对 URI
            let uri = try await createPairingURI(chainId: chainId)
            pairingURI = uri

            // 更新状态为等待确认，UI 层可据此展示 QR 码
            connectionStateSubject.send(.waitingForApproval(uri: uri))

            // 启动超时计时器
            startConnectionTimeout()

            // --------------------------------------------------------
            // 实际集成时，此处通过 WalletConnect SDK 创建配对:
            //
            //   let requiredNamespaces: [String: ProposalNamespace] = [
            //       "eip155": ProposalNamespace(
            //           chains: [Blockchain("eip155:\(chainId)")!],
            //           methods: [
            //               "eth_sendTransaction",
            //               "personal_sign",
            //               "eth_signTypedData"
            //           ],
            //           events: ["chainChanged", "accountsChanged"]
            //       )
            //   ]
            //
            //   let uri = try await Pair.instance.create()
            //   try await Sign.instance.connect(
            //       requiredNamespaces: requiredNamespaces,
            //       topic: uri.topic
            //   )
            //
            //   // URI 字符串用于生成 QR 码或 Deep Link
            //   let wcURI = uri.absoluteString
            // --------------------------------------------------------

            print("[WalletConnect] 配对 URI 已生成, 等待钱包确认...")

        } catch {
            connectionStateSubject.send(.error(error.localizedDescription))
            throw WalletProviderError.connectionFailed(error.localizedDescription)
        }
    }

    /// 生成 WalletConnect v2 配对 URI
    private func createPairingURI(chainId: Int) async throws -> String {
        // --------------------------------------------------------
        // 实际实现:
        //   let uri = try await Pair.instance.create()
        //   return uri.absoluteString
        //
        // 模拟生成符合 WC v2 格式的 URI:
        // wc:{topic}@2?relay-protocol=irn&symKey={symKey}
        // --------------------------------------------------------

        let topic = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let symKey = (0..<32).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()

        let uri = "wc:\(topic)@2?relay-protocol=irn&symKey=\(symKey)"
        return uri
    }

    // MARK: - 发送交易

    /// 发送 ERC20 USDT 转账交易
    func sendTransaction(_ request: TransactionRequest) async throws -> TransactionResult {
        guard let session = activeSession else {
            throw WalletProviderError.notConnected
        }

        guard request.network.isEVM else {
            throw WalletProviderError.unsupportedNetwork
        }

        guard let transferData = request.erc20TransferData else {
            throw WalletProviderError.encodingError
        }

        let chainId = request.network.chainId ?? 1

        // 构建 eth_sendTransaction 参数
        let txParams = EthTransaction(
            from: session.address,
            to: request.network.usdtContractAddress,
            data: transferData,
            chainId: "0x" + String(chainId, radix: 16)
        )

        do {
            let txHash = try await sendEthTransaction(txParams)
            return .success(txHash: txHash)

        } catch let error as WalletProviderError {
            if case .userRejected = error {
                return .rejected
            }
            return .failed(error)
        } catch {
            return .failed(error)
        }
    }

    /// 发送 ERC20 approve 授权交易
    func approve(_ request: ApproveRequest) async throws -> TransactionResult {
        guard let session = activeSession else {
            throw WalletProviderError.notConnected
        }

        guard request.network.isEVM else {
            throw WalletProviderError.unsupportedNetwork
        }

        guard let approveData = request.erc20ApproveData else {
            throw WalletProviderError.encodingError
        }

        let chainId = request.network.chainId ?? 1

        let txParams = EthTransaction(
            from: session.address,
            to: request.network.usdtContractAddress,
            data: approveData,
            chainId: "0x" + String(chainId, radix: 16)
        )

        do {
            let txHash = try await sendEthTransaction(txParams)
            return .success(txHash: txHash)

        } catch let error as WalletProviderError {
            if case .userRejected = error {
                return .rejected
            }
            return .failed(error)
        } catch {
            return .failed(error)
        }
    }

    /// 通过 WalletConnect 发送以太坊交易
    private func sendEthTransaction(_ tx: EthTransaction) async throws -> String {
        guard let session = activeSession else {
            throw WalletProviderError.notConnected
        }

        // --------------------------------------------------------
        // 实际集成时，使用 WalletConnect Sign SDK:
        //
        //   let method = "eth_sendTransaction"
        //   let requestParams = AnyCodable([tx])
        //
        //   let request = Request(
        //       topic: sessionTopic,
        //       method: method,
        //       params: requestParams,
        //       chainId: Blockchain(session.network.caip2Reference)!
        //   )
        //
        //   try await Sign.instance.request(params: request)
        //
        //   // 等待响应
        //   let response = try await withCheckedThrowingContinuation { continuation in
        //       Sign.instance.sessionResponsePublisher
        //           .first()
        //           .sink { response in
        //               switch response.result {
        //               case .response(let value):
        //                   continuation.resume(returning: value.stringValue)
        //               case .error(let error):
        //                   if error.message.contains("rejected") {
        //                       continuation.resume(throwing: WalletProviderError.userRejected)
        //                   } else {
        //                       continuation.resume(throwing: WalletProviderError.transactionFailed(error.message))
        //                   }
        //               }
        //           }
        //           .store(in: &cancellables)
        //   }
        //
        //   return response
        // --------------------------------------------------------

        // 跳转到钱包 App 进行签名
        await openWalletApp()

        print("[WalletConnect] 发送交易: from=\(tx.from), to=\(tx.to), data=\(tx.data)")

        // 模拟异步等待钱包确认
        try await Task.sleep(nanoseconds: 2_000_000_000)

        // 模拟返回交易哈希
        let mockTxHash = "0x" + (0..<32).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
        return mockTxHash
    }

    // MARK: - 断开连接

    /// 断开 WalletConnect 会话
    func disconnect() async throws {
        // --------------------------------------------------------
        // 实际集成:
        //   if let topic = sessionTopic {
        //       try await Sign.instance.disconnect(topic: topic)
        //   }
        // --------------------------------------------------------

        cancelConnectionTimeout()
        activeSession = nil
        pairingURI = nil
        selectedNetwork = nil
        clearStoredSession()
        connectionStateSubject.send(.disconnected)

        print("[WalletConnect] 已断开连接")
    }

    // MARK: - 会话恢复

    /// 尝试恢复上次的 WalletConnect 会话
    func restoreSession() async -> Bool {
        guard let sessionData = UserDefaults.standard.data(forKey: sessionStorageKey),
              let session = try? JSONDecoder().decode(WalletSession.self, from: sessionData) else {
            return false
        }

        // --------------------------------------------------------
        // 实际集成时，验证会话是否仍然活跃:
        //
        //   let activeSessions = Sign.instance.getSessions()
        //   guard let activeSession = activeSessions.first(where: {
        //       $0.peer.name == session.walletName
        //   }) else {
        //       clearStoredSession()
        //       return false
        //   }
        // --------------------------------------------------------

        // 检查会话是否超过 24 小时
        let maxSessionAge: TimeInterval = 24 * 60 * 60
        guard Date().timeIntervalSince(session.connectedAt) < maxSessionAge else {
            clearStoredSession()
            return false
        }

        activeSession = session
        selectedNetwork = session.network
        connectionStateSubject.send(.connected(session))

        print("[WalletConnect] 会话恢复成功: \(session.shortAddress) on \(session.network.rawValue)")
        return true
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

    /// 启动连接超时计时器
    private func startConnectionTimeout() {
        cancelConnectionTimeout()
        connectionTimeoutTask = Task { [weak self] in
            guard let self = self else { return }
            try? await Task.sleep(nanoseconds: UInt64(connectionTimeout * 1_000_000_000))

            guard !Task.isCancelled else { return }

            // 超时后仍在等待，则报告超时错误
            if case .waitingForApproval = self.currentState {
                await MainActor.run {
                    self.connectionStateSubject.send(.error("连接超时，请重试"))
                }
            }
        }
    }

    /// 取消超时计时器
    private func cancelConnectionTimeout() {
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = nil
    }

    // MARK: - 会话事件处理

    /// 处理钱包端确认连接 (WalletConnect 回调)
    func handleSessionSettled(address: String, chainId: Int, walletName: String) {
        cancelConnectionTimeout()

        guard let network = BlockchainNetwork.evmChains.first(where: { $0.chainId == chainId }) else {
            connectionStateSubject.send(.error("不支持的链 ID: \(chainId)"))
            return
        }

        let session = WalletSession(
            id: UUID().uuidString,
            address: address,
            network: network,
            walletName: walletName,
            connectedAt: Date()
        )

        activeSession = session
        saveSession(session)
        connectionStateSubject.send(.connected(session))

        print("[WalletConnect] 会话建立: \(session.shortAddress) on \(network.rawValue)")
    }

    /// 处理钱包端断开连接
    func handleSessionDeleted() {
        activeSession = nil
        clearStoredSession()
        connectionStateSubject.send(.disconnected)
        print("[WalletConnect] 钱包端主动断开连接")
    }

    // MARK: - Deep Link 跳转

    /// 打开钱包 App (通过 Deep Link / Universal Link)
    private func openWalletApp() async {
        guard let session = activeSession else { return }

        // 根据钱包名称匹配对应的 URL Scheme
        let walletInfo = SupportedWallets.all.first { $0.name == session.walletName }

        guard let scheme = walletInfo?.deepLinkScheme,
              let url = URL(string: scheme) else {
            return
        }

        await MainActor.run {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }

    /// 通过 WalletConnect URI 唤起指定钱包
    func openWalletWithURI(_ walletInfo: WalletAppInfo, uri: String) {
        let encodedURI = uri.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? uri

        var deepLinkURL: URL?

        // 优先使用 Universal Link
        if let universalLink = walletInfo.universalLink {
            deepLinkURL = URL(string: "\(universalLink)/wc?uri=\(encodedURI)")
        }

        // 降级到 URL Scheme
        if deepLinkURL == nil {
            deepLinkURL = URL(string: "\(walletInfo.deepLinkScheme)wc?uri=\(encodedURI)")
        }

        guard let url = deepLinkURL else { return }

        DispatchQueue.main.async {
            UIApplication.shared.open(url) { success in
                if !success {
                    print("[WalletConnect] 无法打开钱包: \(walletInfo.name)")
                }
            }
        }
    }

    /// 检测钱包 App 是否已安装
    func isWalletInstalled(_ walletInfo: WalletAppInfo) -> Bool {
        guard let url = URL(string: walletInfo.deepLinkScheme) else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    // MARK: - 模拟连接 (开发调试用)

    #if DEBUG
    /// 模拟钱包连接成功 (开发调试)
    func simulateConnection(network: BlockchainNetwork) {
        let mockAddress: String
        switch network {
        case .ethereum:
            mockAddress = "0x742d35Cc6634C0532925a3b844Bc9e7595f2bD15"
        case .bsc:
            mockAddress = "0x8894E0a0c962CB723c1ef8c0B83eC2E45b0E8c55"
        case .polygon:
            mockAddress = "0xAb5801a7D398351b8bE11C439e05C5B3259aec9B"
        default:
            return
        }

        handleSessionSettled(
            address: mockAddress,
            chainId: network.chainId ?? 1,
            walletName: "MetaMask"
        )
    }
    #endif
}

// MARK: - 以太坊交易参数

/// eth_sendTransaction 的参数结构
struct EthTransaction: Codable {
    let from: String       // 发送方地址
    let to: String         // 合约地址 (USDT 合约)
    let data: String       // ABI 编码数据
    let chainId: String    // 链 ID (十六进制)
    var value: String = "0x0"  // ETH 转账额 (ERC20 操作为 0)
    var gas: String?       // Gas 限制 (可选，钱包会自动估算)
}

// MARK: - URL 处理扩展

extension WalletConnectProvider {

    /// 处理从钱包 App 返回的 Deep Link 回调
    /// 在 AppDelegate / SceneDelegate 的 openURL 中调用
    func handleDeepLinkCallback(url: URL) {
        // WalletConnect v2 回调处理
        // 实际集成时 SDK 会自动处理大部分回调
        print("[WalletConnect] 收到回调 URL: \(url.absoluteString)")

        // 解析回调中的会话信息
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return
        }

        // 检查是否为 WalletConnect 回调
        if components.scheme == "epusdtpay" {
            if let wcURI = components.queryItems?.first(where: { $0.name == "wc" })?.value {
                print("[WalletConnect] 接收到 WC URI: \(wcURI)")
            }
        }
    }
}
