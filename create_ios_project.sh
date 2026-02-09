#!/bin/bash

# Epusdt iOS 项目初始化脚本
# 使用方法: bash create_ios_project.sh

set -e

PROJECT_NAME="EpusdtPay"
TEAM_ID=""  # 你的 Apple Team ID
ORGANIZATION="Epusdt"
BUNDLE_ID="com.epusdt.pay"

echo "🚀 开始创建 Epusdt iOS 项目..."
echo ""

# 创建项目目录
mkdir -p ~/Developer/$PROJECT_NAME
cd ~/Developer/$PROJECT_NAME

echo "📁 创建项目目录结构..."

# 创建主目录
mkdir -p $PROJECT_NAME/{App,Views,ViewModels,Models,Services,Utilities,Resources}

# 创建子目录
mkdir -p $PROJECT_NAME/Views/{Authentication,Merchant,Customer,Common}
mkdir -p $PROJECT_NAME/Resources/{Assets.xcassets,Localization}

# 创建测试目录
mkdir -p ${PROJECT_NAME}Tests

echo "📝 创建项目文件..."

# 1. 创建 SwiftUI App 入口
cat > $PROJECT_NAME/App/EpusdtPayApp.swift << 'EOF'
import SwiftUI

@main
struct EpusdtPayApp: App {
    @StateObject var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            if authViewModel.isLoggedIn {
                TabBarView()
                    .environmentObject(authViewModel)
            } else {
                LoginView()
                    .environmentObject(authViewModel)
            }
        }
    }
}
EOF

# 2. 创建基础模型
cat > $PROJECT_NAME/Models/User.swift << 'EOF'
import Foundation

struct User: Codable, Identifiable {
    let id: String
    let phone: String
    let email: String?
    let role: UserRole
    let status: Int
    let createdAt: Date?

    enum UserRole: String, Codable {
        case merchant  // 商户
        case customer  // 客户
        case admin     // 管理员
    }
}

struct AuthResponse: Codable {
    let token: String
    let user: User
}
EOF

# 3. 创建认证 ViewModel
cat > $PROJECT_NAME/ViewModels/AuthViewModel.swift << 'EOF'
import SwiftUI
import Combine

class AuthViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var currentUser: User?
    @Published var errorMessage: String?

    func login(phone: String, password: String) async {
        do {
            let response: AuthResponse = try await APIService.shared.request(
                endpoint: "/auth/login",
                method: .post,
                parameters: ["phone": phone, "password": password]
            )

            DispatchQueue.main.async {
                self.isLoggedIn = true
                self.currentUser = response.user
                // 保存 token 到钥匙串
                KeychainManager.save(response.token, for: "auth_token")
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func logout() {
        isLoggedIn = false
        currentUser = nil
        KeychainManager.delete("auth_token")
    }
}
EOF

# 4. 创建 API 服务
cat > $PROJECT_NAME/Services/APIService.swift << 'EOF'
import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

class APIService {
    static let shared = APIService()

    private let baseURL = "http://localhost:8000/api"
    private let session = URLSession.shared

    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        parameters: [String: Any]? = nil
    ) async throws -> T {
        let url = URL(string: baseURL + endpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // 添加认证 Token
        if let token = KeychainManager.load("auth_token") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let parameters = parameters {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}
EOF

# 5. 创建钥匙串管理器
cat > $PROJECT_NAME/Utilities/KeychainManager.swift << 'EOF'
import Foundation
import Security

class KeychainManager {
    static func save(_ value: String, for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: value.data(using: .utf8)!
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data else { return nil }

        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}
EOF

# 6. 创建登录视图
cat > $PROJECT_NAME/Views/Authentication/LoginView.swift << 'EOF'
import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var phone = ""
    @State private var password = ""
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Epusdt Pay")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Color(hex: "#d4af37"))

            VStack(spacing: 16) {
                TextField("手机号", text: $phone)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.phonePad)

                SecureField("密码", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Button(action: {
                    isLoading = true
                    Task {
                        await authViewModel.login(phone: phone, password: password)
                        isLoading = false
                    }
                }) {
                    Text("登录")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "#d4af37"))
                        .foregroundColor(.black)
                        .cornerRadius(8)
                }
                .disabled(isLoading)

                if let error = authViewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding()

            Spacer()
        }
        .padding()
        .background(Color(hex: "#0f1218"))
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
EOF

# 7. 创建底部导航
cat > $PROJECT_NAME/Views/Common/TabBarView.swift << 'EOF'
import SwiftUI

struct TabBarView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        TabView {
            // 首页
            MerchantHomeView()
                .tabItem {
                    Label("收款", systemImage: "qrcode")
                }

            // 支付
            ScanQRView()
                .tabItem {
                    Label("支付", systemImage: "camera")
                }

            // 钱包
            WalletView()
                .tabItem {
                    Label("钱包", systemImage: "wallet.pass")
                }

            // 我的
            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person")
                }
        }
        .tint(Color(hex: "#d4af37"))
    }
}

// 占位视图
struct MerchantHomeView: View {
    var body: some View {
        Text("收款页面")
    }
}

struct ScanQRView: View {
    var body: some View {
        Text("扫码支付")
    }
}

struct WalletView: View {
    var body: some View {
        Text("钱包管理")
    }
}

struct ProfileView: View {
    var body: some View {
        Text("个人信息")
    }
}

#Preview {
    TabBarView()
        .environmentObject(AuthViewModel())
}
EOF

# 8. 创建颜色扩展
cat > $PROJECT_NAME/Utilities/Extensions.swift << 'EOF'
import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)

        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
EOF

# 9. 创建常量文件
cat > $PROJECT_NAME/Utilities/Constants.swift << 'EOF'
import Foundation

struct Constants {
    // API
    static let baseURL = "http://localhost:8000/api"

    // 颜色
    struct Colors {
        static let primary = "#d4af37"      // 金色
        static let background = "#0f1218"   // 深黑
        static let card = "#171c25"         // 深灰
        static let text = "#e6e6e6"         // 浅白
        static let success = "#2ecc71"      // 绿色
        static let error = "#e74c3c"        // 红色
    }

    // 支持的链
    struct Chains {
        static let supported = ["TRON", "BSC", "EVM", "POLYGON"]
    }
}
EOF

echo "✅ 项目结构创建完成！"
echo ""
echo "📋 接下来的步骤："
echo "1. 使用 Xcode 打开项目"
echo "2. 配置 Podfile"
echo "3. 运行 pod install"
echo "4. 开始开发"
echo ""
echo "项目路径: ~/Developer/$PROJECT_NAME"
