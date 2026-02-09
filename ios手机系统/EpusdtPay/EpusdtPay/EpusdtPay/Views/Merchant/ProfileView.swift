//
//  ProfileView.swift
//  EpusdtPay
//
//  User profile and settings
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showThemeSettings = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // MARK: - User Info Card
                VStack(spacing: 12) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.gold)

                    Text(authViewModel.currentUser?.username ?? authViewModel.merchantProfile?.username ?? "未知用户")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.textPrimary)

                    HStack(spacing: 8) {
                        if authViewModel.isMerchantUser {
                            StatusBadge(text: "商家", color: .gold)
                        } else {
                            StatusBadge(
                                text: authViewModel.currentUser?.roleText ?? "用户",
                                color: .gold
                            )
                        }
                        StatusBadge(
                            text: authViewModel.currentUser?.status == 1 ? "正常" : (authViewModel.isMerchantUser ? "正常" : "禁用"),
                            color: .statusSuccess
                        )
                    }
                }
                .padding(24)

                // MARK: - Menu Items
                VStack(spacing: 1) {
                    // Theme Settings
                    Button(action: { showThemeSettings = true }) {
                        ProfileMenuItem(
                            icon: themeManager.currentTheme.icon,
                            title: "主题设置",
                            subtitle: themeManager.currentTheme.displayName
                        )
                    }
                    .buttonStyle(.plain)
                    
                    ProfileMenuItem(icon: "info.circle", title: "关于", subtitle: "v\(AppConfig.version)")
                }
                .background(Color.bgSecondary)
                .cornerRadius(12)
                .padding(.horizontal, 16)

                Spacer()

                // MARK: - Logout Button
                Button(action: authViewModel.logout) {
                    Text("退出登录")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(Color.statusError.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("我的")
            .darkBackground()
            .sheet(isPresented: $showThemeSettings) {
                ThemeSettingsView()
                    .environmentObject(themeManager)
            }
        }
    }
}

// MARK: - Profile Menu Item
struct ProfileMenuItem: View {
    let icon: String
    let title: String
    var subtitle: String = ""

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.gold)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.textPrimary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.textSecondary)
        }
        .padding(14)
        .background(Color.bgCard)
    }
}
