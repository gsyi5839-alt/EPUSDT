//
//  WalletConnectionProvider.swift
//  EpusdtPay
//
//  钱包连接协议定义 & 通用数据模型
//  所有钱包提供者 (WalletConnect / TronLink) 均需遵循此协议
//

import Foundation
import Combine

// MARK: - 支持的区块链网络

/// 区块链网络枚举，包含 EVM 兼容链和 TRON
enum BlockchainNetwork: String, CaseIterable, Identifiable, Codable {
    case ethereum = "Ethereum"
    case bsc = "BSC"
    case polygon = "Polygon"
    case tron = "TRON"

    var id: String { rawValue }

    /// EVM 链 ID (TRON 不适用)
    var chainId: Int? {
        switch self {
        case .ethereum: return 1
        case .bsc: return 56
        case .polygon: return 137
        case .tron: return nil
        }
    }

    /// CAIP-2 命名空间标识符
    var caip2Namespace: String {
        switch self {
        case .ethereum, .bsc, .polygon: return "eip155"
        case .tron: return "tron"
        }
    }

    /// CAIP-2 完整链引用 (例: "eip155:1")
    var caip2Reference: String {
        switch self {
        case .ethereum: return "eip155:1"
        case .bsc: return "eip155:56"
        case .polygon: return "eip155:137"
        case .tron: return "tron:mainnet"
        }
    }

    /// 该链上 USDT 合约地址
    var usdtContractAddress: String {
        switch self {
        case .ethereum: return "0xdAC17F958D2ee523a2206206994597C13D831ec7"
        case .bsc: return "0x55d398326f99059fF775485246999027B3197955"
        case .polygon: return "0xc2132D05D31c914a87C6611C10748AEb04B58e8F"
        case .tron: return "TR7NHqjeKQxGTCi8q282RJWC3SVrFoJypL"
        }
    }

    /// USDT 精度 (ERC20/BEP20/TRC20 均为 6 位小数)
    var usdtDecimals: Int {
        return 6
    }

    /// 网络图标 (SF Symbols)
    var iconName: String {
        switch self {
        case .ethereum: return "diamond.fill"
        case .bsc: return "circle.hexagongrid.fill"
        case .polygon: return "pentagon.fill"
        case .tron: return "bolt.fill"
        }
    }

    /// 网络品牌颜色
    var brandColorHex: Int {
        switch self {
        case .ethereum: return 0x627EEA
        case .bsc: return 0xF3BA2F
        case .polygon: return 0x8247E5
        case .tron: return 0xEB0029
        }
    }

    /// 区块浏览器基础 URL
    var explorerBaseURL: String {
        switch self {
        case .ethereum: return "https://etherscan.io"
        case .bsc: return "https://bscscan.com"
        case .polygon: return "https://polygonscan.com"
        case .tron: return "https://tronscan.org"
        }
    }

    /// 交易哈希浏览器 URL
    func explorerURL(txHash: String) -> URL? {
        switch self {
        case .tron:
            return URL(string: "\(explorerBaseURL)/#/transaction/\(txHash)")
        default:
            return URL(string: "\(explorerBaseURL)/tx/\(txHash)")
        }
    }

    /// 是否为 EVM 兼容链
    var isEVM: Bool {
        switch self {
        case .ethereum, .bsc, .polygon: return true
        case .tron: return false
        }
    }

    /// EVM 兼容链列表
    static var evmChains: [BlockchainNetwork] {
        allCases.filter { $0.isEVM }
    }
}

// MARK: - 钱包会话模型

/// 表示一个已连接的钱包会话
struct WalletSession: Codable, Identifiable, Equatable {
    let id: String
    let address: String
    let network: BlockchainNetwork
    let walletName: String
    let connectedAt: Date

    /// 缩短的钱包地址 (例: 0x1234...abcd)
    var shortAddress: String {
        guard address.count > 10 else { return address }
        let prefix = String(address.prefix(6))
        let suffix = String(address.suffix(4))
        return "\(prefix)...\(suffix)"
    }

    static func == (lhs: WalletSession, rhs: WalletSession) -> Bool {
        lhs.id == rhs.id && lhs.address == rhs.address
    }
}

// MARK: - 交易请求模型

/// ERC20/TRC20 USDT 转账请求
struct TransactionRequest {
    let toAddress: String          // 收款地址
    let amount: Decimal            // USDT 数量 (人类可读，如 100.50)
    let network: BlockchainNetwork // 目标网络

    /// 将 USDT 数量转换为最小单位 (考虑精度)
    var amountInSmallestUnit: String {
        let multiplier = Decimal(pow(10.0, Double(network.usdtDecimals)))
        let rawAmount = amount * multiplier
        return "\(rawAmount)"
    }

    /// ERC20 transfer 函数的 ABI 编码数据
    /// transfer(address,uint256) = 0xa9059cbb
    var erc20TransferData: String? {
        guard network.isEVM else { return nil }

        // 函数选择器: transfer(address,uint256) -> 0xa9059cbb
        let selector = "a9059cbb"

        // 编码目标地址 (去掉 0x 前缀，左填充到 64 字符)
        let cleanAddress = toAddress.hasPrefix("0x")
            ? String(toAddress.dropFirst(2))
            : toAddress
        let paddedAddress = String(repeating: "0", count: 64 - cleanAddress.count) + cleanAddress

        // 编码金额 (转换为 hex，左填充到 64 字符)
        let multiplier = Decimal(pow(10.0, Double(network.usdtDecimals)))
        let rawAmount = amount * multiplier
        let intAmount = NSDecimalNumber(decimal: rawAmount).uint64Value
        let hexAmount = String(intAmount, radix: 16)
        let paddedAmount = String(repeating: "0", count: 64 - hexAmount.count) + hexAmount

        return "0x" + selector + paddedAddress + paddedAmount
    }
}

// MARK: - 授权请求模型

/// ERC20 approve 请求 (用于授权合约扣款)
struct ApproveRequest {
    let spenderAddress: String     // 被授权地址
    let amount: Decimal            // 授权 USDT 数量
    let network: BlockchainNetwork // 目标网络

    /// ERC20 approve 函数的 ABI 编码数据
    /// approve(address,uint256) = 0x095ea7b3
    var erc20ApproveData: String? {
        guard network.isEVM else { return nil }

        let selector = "095ea7b3"

        let cleanAddress = spenderAddress.hasPrefix("0x")
            ? String(spenderAddress.dropFirst(2))
            : spenderAddress
        let paddedAddress = String(repeating: "0", count: 64 - cleanAddress.count) + cleanAddress

        let multiplier = Decimal(pow(10.0, Double(network.usdtDecimals)))
        let rawAmount = amount * multiplier
        let intAmount = NSDecimalNumber(decimal: rawAmount).uint64Value
        let hexAmount = String(intAmount, radix: 16)
        let paddedAmount = String(repeating: "0", count: 64 - hexAmount.count) + hexAmount

        return "0x" + selector + paddedAddress + paddedAmount
    }

    /// 无限授权的 ABI 编码数据 (amount = uint256 max)
    var erc20UnlimitedApproveData: String? {
        guard network.isEVM else { return nil }

        let selector = "095ea7b3"

        let cleanAddress = spenderAddress.hasPrefix("0x")
            ? String(spenderAddress.dropFirst(2))
            : spenderAddress
        let paddedAddress = String(repeating: "0", count: 64 - cleanAddress.count) + cleanAddress

        // uint256 最大值
        let maxUint256 = String(repeating: "f", count: 64)

        return "0x" + selector + paddedAddress + maxUint256
    }
}

// MARK: - 连接状态

/// 钱包连接状态枚举
enum WalletConnectionState: Equatable {
    case disconnected                    // 未连接
    case connecting                      // 正在连接
    case waitingForApproval(uri: String) // 等待用户在钱包中确认，uri 用于 QR 码
    case connected(WalletSession)        // 已连接
    case error(String)                   // 连接出错

    static func == (lhs: WalletConnectionState, rhs: WalletConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected):
            return true
        case (.connecting, .connecting):
            return true
        case (.waitingForApproval(let a), .waitingForApproval(let b)):
            return a == b
        case (.connected(let a), .connected(let b)):
            return a == b
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - 交易结果

/// 交易发送结果
enum TransactionResult {
    case success(txHash: String)     // 交易已广播，返回哈希
    case rejected                     // 用户拒绝签名
    case failed(Error)                // 发送失败
}

// MARK: - 钱包连接提供者协议

/// 所有钱包连接方式必须遵循的协议
protocol WalletConnectionProvider: AnyObject {

    /// 当前连接状态 (Publisher，供 UI 监听)
    var connectionStatePublisher: AnyPublisher<WalletConnectionState, Never> { get }

    /// 当前连接状态
    var currentState: WalletConnectionState { get }

    /// 支持的区块链网络列表
    var supportedNetworks: [BlockchainNetwork] { get }

    /// 发起钱包连接
    /// - Parameter network: 目标区块链网络
    func connect(network: BlockchainNetwork) async throws

    /// 发送 USDT 转账交易
    /// - Parameter request: 交易请求参数
    /// - Returns: 交易结果
    func sendTransaction(_ request: TransactionRequest) async throws -> TransactionResult

    /// 发送 ERC20/TRC20 approve 授权交易
    /// - Parameter request: 授权请求参数
    /// - Returns: 交易结果
    func approve(_ request: ApproveRequest) async throws -> TransactionResult

    /// 断开钱包连接
    func disconnect() async throws

    /// 尝试恢复上次的会话
    func restoreSession() async -> Bool
}

// MARK: - 钱包提供者错误

/// 钱包操作相关错误
enum WalletProviderError: LocalizedError {
    case notConnected                      // 钱包未连接
    case connectionFailed(String)          // 连接失败
    case transactionFailed(String)         // 交易失败
    case userRejected                      // 用户拒绝操作
    case unsupportedNetwork                // 不支持的网络
    case walletAppNotInstalled(String)     // 钱包 App 未安装
    case sessionExpired                    // 会话过期
    case invalidAddress                    // 无效地址
    case encodingError                     // 数据编码错误
    case timeout                           // 操作超时

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "钱包未连接，请先连接钱包"
        case .connectionFailed(let reason):
            return "连接失败: \(reason)"
        case .transactionFailed(let reason):
            return "交易失败: \(reason)"
        case .userRejected:
            return "用户取消了操作"
        case .unsupportedNetwork:
            return "不支持的区块链网络"
        case .walletAppNotInstalled(let name):
            return "\(name) 未安装，请先安装钱包应用"
        case .sessionExpired:
            return "会话已过期，请重新连接钱包"
        case .invalidAddress:
            return "无效的钱包地址"
        case .encodingError:
            return "交易数据编码失败"
        case .timeout:
            return "操作超时，请重试"
        }
    }
}

// MARK: - 支持的钱包应用信息

/// 钱包应用元数据 (用于 UI 展示和 Deep Link 跳转)
struct WalletAppInfo: Identifiable {
    let id: String
    let name: String
    let iconName: String          // SF Symbol 图标名
    let deepLinkScheme: String    // URL Scheme (例: metamask://)
    let universalLink: String?    // Universal Link
    let supportedNetworks: [BlockchainNetwork]
    let providerType: ProviderType

    enum ProviderType {
        case walletConnect   // 通过 WalletConnect 协议连接
        case tronLink        // 通过 TronLink Deep Link 连接
    }
}

/// 预定义的支持钱包列表
struct SupportedWallets {
    static let all: [WalletAppInfo] = [
        WalletAppInfo(
            id: "metamask",
            name: "MetaMask",
            iconName: "m.circle.fill",
            deepLinkScheme: "metamask://",
            universalLink: "https://metamask.app.link",
            supportedNetworks: BlockchainNetwork.evmChains,
            providerType: .walletConnect
        ),
        WalletAppInfo(
            id: "trust",
            name: "Trust Wallet",
            iconName: "shield.checkered",
            deepLinkScheme: "trust://",
            universalLink: "https://link.trustwallet.com",
            supportedNetworks: BlockchainNetwork.evmChains,
            providerType: .walletConnect
        ),
        WalletAppInfo(
            id: "tokenpocket",
            name: "TokenPocket",
            iconName: "t.circle.fill",
            deepLinkScheme: "tpoutside://",
            universalLink: nil,
            supportedNetworks: BlockchainNetwork.allCases.map { $0 },
            providerType: .walletConnect
        ),
        WalletAppInfo(
            id: "tronlink",
            name: "TronLink",
            iconName: "bolt.circle.fill",
            deepLinkScheme: "tronlinkoutside://",
            universalLink: nil,
            supportedNetworks: [.tron],
            providerType: .tronLink
        )
    ]

    /// 根据网络筛选可用钱包
    static func wallets(for network: BlockchainNetwork) -> [WalletAppInfo] {
        all.filter { $0.supportedNetworks.contains(network) }
    }

    /// 获取 EVM 链可用的钱包
    static var evmWallets: [WalletAppInfo] {
        all.filter { $0.providerType == .walletConnect }
    }

    /// 获取 TRON 链可用的钱包
    static var tronWallets: [WalletAppInfo] {
        all.filter { $0.supportedNetworks.contains(.tron) }
    }
}
