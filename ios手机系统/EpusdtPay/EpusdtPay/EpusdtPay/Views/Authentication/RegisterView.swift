//
//  RegisterView.swift
//  EpusdtPay
//
//  Merchant registration view
//

import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var merchantName = ""
    @State private var walletToken = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showPassword = false

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.bgPrimary, Color.bgSecondary]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.title3)
                                .foregroundColor(.gold)
                        }
                        Spacer()
                        Text("商家注册")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.textPrimary)
                        Spacer()
                        Color.clear.frame(width: 24)
                    }
                    .padding(16)

                    // Form
                    VStack(spacing: 16) {
                        // Username
                        formField(title: "用户名", placeholder: "请输入用户名（至少3个字符）", text: $username)

                        // Merchant Name
                        formField(title: "商家名称", placeholder: "请输入商家/店铺名称", text: $merchantName)

                        // Wallet Token
                        VStack(alignment: .leading, spacing: 8) {
                            Text("钱包地址")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                            TextField("USDT 收款钱包地址（TRON/EVM）", text: $walletToken)
                                .autocapitalization(.none)
                                .padding(12)
                                .background(Color.bgInput)
                                .cornerRadius(8)
                                .foregroundColor(.textPrimary)
                            Text("用于接收客户授权支付的 USDT")
                                .font(.system(size: 11))
                                .foregroundColor(.textMuted)
                        }

                        // Password
                        VStack(alignment: .leading, spacing: 8) {
                            Text("密码")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                            HStack {
                                if showPassword {
                                    TextField("请输入密码（至少6位）", text: $password)
                                } else {
                                    SecureField("请输入密码（至少6位）", text: $password)
                                }
                                Button(action: { showPassword.toggle() }) {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundColor(.textSecondary)
                                }
                            }
                            .padding(12)
                            .background(Color.bgInput)
                            .cornerRadius(8)
                        }

                        // Confirm Password
                        VStack(alignment: .leading, spacing: 8) {
                            Text("确认密码")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                            SecureField("再次输入密码", text: $confirmPassword)
                                .padding(12)
                                .background(Color.bgInput)
                                .cornerRadius(8)
                                .foregroundColor(.textPrimary)
                        }

                        // Error
                        if !errorMessage.isEmpty {
                            HStack {
                                Image(systemName: "exclamationmark.circle")
                                    .foregroundColor(.statusError)
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(.statusError)
                                Spacer()
                            }
                            .padding(12)
                            .background(Color.statusError.opacity(0.1))
                            .cornerRadius(8)
                        }

                        // Register Button
                        Button(action: registerUser) {
                            if isLoading {
                                ProgressView()
                                    .tint(Color.accentText)
                            } else {
                                Text("注册")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(isFormValid ? Color.gold : Color.gold.opacity(0.4))
                        .foregroundColor(Color.accentText)
                        .cornerRadius(8)
                        .disabled(isLoading || !isFormValid)
                    }
                    .padding(20)
                    .background(Color.bgSecondary)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)

                    // Login Link
                    HStack(spacing: 4) {
                        Text("已有账号？")
                            .foregroundColor(.textSecondary)
                        Button(action: { dismiss() }) {
                            Text("返回登录")
                                .foregroundColor(.gold)
                                .fontWeight(.semibold)
                        }
                    }
                    .font(.caption)

                    Spacer().frame(height: 40)
                }
            }
        }
    }

    private var isFormValid: Bool {
        !username.isEmpty && !password.isEmpty && !confirmPassword.isEmpty &&
        !merchantName.isEmpty && !walletToken.isEmpty &&
        username.count >= 3 && password.count >= 6
    }

    @ViewBuilder
    private func formField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.textSecondary)
            TextField(placeholder, text: text)
                .autocapitalization(.none)
                .padding(12)
                .background(Color.bgInput)
                .cornerRadius(8)
                .foregroundColor(.textPrimary)
        }
    }

    private func registerUser() {
        // Validation
        guard password == confirmPassword else {
            errorMessage = "两次输入的密码不一致"
            return
        }
        guard username.count >= 3 else {
            errorMessage = "用户名至少3个字符"
            return
        }
        guard password.count >= 6 else {
            errorMessage = "密码至少6位"
            return
        }

        isLoading = true
        errorMessage = ""

        authViewModel.register(
            username: username,
            password: password,
            email: "",
            merchantName: merchantName,
            walletToken: walletToken
        ) { success, error in
            DispatchQueue.main.async {
                isLoading = false
                if success {
                    dismiss()
                } else {
                    errorMessage = error ?? "注册失败"
                }
            }
        }
    }
}

#Preview {
    RegisterView()
        .environmentObject(AuthViewModel())
}
