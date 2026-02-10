//
//  WalletManageView.swift
//  EpusdtPay
//
//  Wallet address management
//

import SwiftUI

struct WalletManageView: View {
    @EnvironmentObject var walletVM: WalletViewModel
    @State private var showAddSheet = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // MARK: - Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("钱包地址")
                            .font(.headline)
                            .foregroundColor(.textPrimary)
                        Text("\(walletVM.wallets.count) 个地址")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                    Spacer()
                    Button(action: { showAddSheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("添加")
                        }
                        .font(.subheadline)
                        .foregroundColor(.gold)
                    }
                }
                .padding(16)

                // Error/Success
                if let error = walletVM.errorMessage {
                    ErrorBanner(message: error, onDismiss: { walletVM.errorMessage = nil })
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }

                // MARK: - Wallet List
                if walletVM.isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .gold))
                    Spacer()
                } else if walletVM.wallets.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "wallet.pass")
                            .font(.system(size: 40))
                            .foregroundColor(.textSecondary)
                        Text("暂无钱包地址")
                            .foregroundColor(.textSecondary)
                        Text("点击右上角「添加」来添加收款地址")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(walletVM.wallets) { wallet in
                                WalletRowView(
                                    wallet: wallet,
                                    onToggle: { walletVM.toggleWalletStatus(wallet) },
                                    onDelete: { walletVM.deleteWallet(wallet) }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .refreshable { walletVM.loadWallets() }
                }
            }
            .navigationTitle("钱包")
            .darkBackground()
            .onAppear { walletVM.loadWallets() }
            .sheet(isPresented: $showAddSheet) {
                AddWalletSheet(walletVM: walletVM, isPresented: $showAddSheet)
            }
        }
    }
}

// MARK: - Wallet Row
struct WalletRowView: View {
    let wallet: WalletAddress
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(wallet.token)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    ChainBadge(chain: wallet.chain)
                    StatusBadge(
                        text: wallet.isEnabled ? "启用" : "禁用",
                        color: wallet.isEnabled ? .statusSuccess : .statusError
                    )
                }
            }

            Spacer()

            VStack(spacing: 8) {
                Toggle("", isOn: Binding(
                    get: { wallet.isEnabled },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .gold))
                .labelsHidden()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.statusError.opacity(0.7))
                }
            }
        }
        .padding(12)
        .background(Color.bgCard)
        .cornerRadius(8)
    }
}

// MARK: - Add Wallet Sheet
struct AddWalletSheet: View {
    @ObservedObject var walletVM: WalletViewModel
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                FormField(
                    label: "钱包地址",
                    placeholder: "输入 USDT 收款地址",
                    text: $walletVM.newWalletToken
                )

                ChainPicker(selected: $walletVM.newWalletChain)

                if let error = walletVM.errorMessage {
                    ErrorBanner(message: error, onDismiss: { walletVM.errorMessage = nil })
                }

                GoldButton(
                    title: "添加钱包",
                    isLoading: walletVM.isLoading
                ) {
                    walletVM.addWallet()
                    if walletVM.errorMessage == nil {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            if walletVM.successMessage != nil {
                                isPresented = false
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("添加钱包")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        isPresented = false
                    }
                    .foregroundColor(.gold)
                }
            }
            .darkBackground()
        }
    }
}
