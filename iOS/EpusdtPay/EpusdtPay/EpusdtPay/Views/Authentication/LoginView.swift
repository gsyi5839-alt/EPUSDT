//
//  LoginView.swift
//  EpusdtPay
//
//  User authentication and login view
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var username = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showRegister = false
    @State private var isMerchantLogin = true // 默认商家登录

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    gradient: Gradient(colors: [Color.bgPrimary, Color.bgSecondary]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Logo & Title
                        VStack(spacing: 12) {
                            Image(systemName: "bitcoinsign.circle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.gold)

                            Text("Epusdt Pay")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.textPrimary)

                            Text("USDT 支付系统")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                        .padding(.top, 40)

                        // Login Type Switcher
                        HStack(spacing: 0) {
                            Button(action: { isMerchantLogin = true; errorMessage = "" }) {
                                Text("商家登录")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(isMerchantLogin ? Color.gold : Color.clear)
                                    .foregroundColor(isMerchantLogin ? Color.accentText : Color.textSecondary)
                            }

                            Button(action: { isMerchantLogin = false; errorMessage = "" }) {
                                Text("管理员登录")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(!isMerchantLogin ? Color.gold : Color.clear)
                                    .foregroundColor(!isMerchantLogin ? Color.accentText : Color.textSecondary)
                            }
                        }
                        .background(Color.bgInput)
                        .cornerRadius(8)
                        .padding(.horizontal, 20)

                        // Form
                        VStack(spacing: 16) {
                            // Username Input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("用户名")
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)

                                TextField("请输入用户名", text: $username)
                                    .textContentType(.username)
                                    .autocapitalization(.none)
                                    .padding(12)
                                    .background(Color.bgInput)
                                    .cornerRadius(8)
                                    .foregroundColor(.textPrimary)
                            }

                            // Password Input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("密码")
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)

                                HStack {
                                    if showPassword {
                                        TextField("请输入密码", text: $password)
                                            .textContentType(.password)
                                    } else {
                                        SecureField("请输入密码", text: $password)
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

                            // Error Message
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

                            // Login Button
                            Button(action: loginUser) {
                                if isLoading {
                                    ProgressView()
                                        .tint(Color.accentText)
                                } else {
                                    Text("登录")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(Color.gold)
                            .foregroundColor(Color.accentText)
                            .cornerRadius(8)
                            .disabled(isLoading || username.isEmpty || password.isEmpty)
                        }
                        .padding(20)
                        .background(Color.bgSecondary)
                        .cornerRadius(12)

                        // Register Link (商家登录模式才显示)
                        if isMerchantLogin {
                            HStack(spacing: 4) {
                                Text("还没有账号？")
                                    .foregroundColor(.textSecondary)
                                Button(action: { showRegister = true }) {
                                    Text("立即注册")
                                        .foregroundColor(.gold)
                                        .fontWeight(.semibold)
                                }
                            }
                            .font(.caption)
                        } else {
                            HStack(spacing: 4) {
                                Text("管理员账号由系统创建")
                                    .foregroundColor(.textSecondary)
                            }
                            .font(.caption)
                        }

                        Spacer()
                    }
                    .padding(20)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showRegister) {
                RegisterView()
                    .environmentObject(authViewModel)
                    .environmentObject(themeManager)
            }
        }
    }

    private func loginUser() {
        isLoading = true
        errorMessage = ""

        if isMerchantLogin {
            authViewModel.merchantLogin(username: username, password: password) { success, error in
                DispatchQueue.main.async {
                    isLoading = false
                    if !success {
                        errorMessage = error ?? "登录失败"
                    }
                }
            }
        } else {
            authViewModel.login(username: username, password: password) { success, error in
                DispatchQueue.main.async {
                    isLoading = false
                    if !success {
                        errorMessage = error ?? "登录失败"
                    }
                }
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}

