//
//  WithdrawalView.swift
//  EpusdtPay
//
//  Merchant withdrawal request and history view
//

import SwiftUI

struct WithdrawalView: View {
    @EnvironmentObject var merchantVM: MerchantViewModel
    @EnvironmentObject var walletViewModel: WalletViewModel
    @Environment(\.dismiss) var dismiss

    @State private var amount = ""
    @State private var selectedWallet = ""
    @State private var showSuccess = false
    @State private var showError = false

    private var enabledWallets: [WalletAddress] {
        walletViewModel.wallets.filter { $0.isEnabled }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    balanceHeader
                    withdrawalForm
                    withdrawalHistory
                }
                .padding(.vertical, 16)
            }
            .navigationTitle("提现")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(.gold)
                }
            }
            .darkBackground()
            .onAppear {
                merchantVM.loadBalance()
                merchantVM.loadWithdrawals()
                walletViewModel.loadWallets()
                if selectedWallet.isEmpty, let first = enabledWallets.first {
                    selectedWallet = first.token
                }
            }
            .onChange(of: walletViewModel.wallets.map { $0.id }) {
                if selectedWallet.isEmpty, let first = enabledWallets.first {
                    selectedWallet = first.token
                }
            }
            .alert("提现申请成功", isPresented: $showSuccess) {
                Button("确定") {
                    amount = ""
                    merchantVM.withdrawalSuccess = false
                }
            } message: {
                Text("提现申请已提交，请等待管理员审批。")
            }
            .alert("提现失败", isPresented: $showError) {
                Button("确定") { merchantVM.errorMessage = nil }
            } message: {
                Text(merchantVM.errorMessage ?? "未知错误")
            }
            .onChange(of: merchantVM.withdrawalSuccess) {
                if merchantVM.withdrawalSuccess {
                    showSuccess = true
                }
            }
            .onChange(of: merchantVM.errorMessage) {
                if merchantVM.errorMessage != nil && merchantVM.isWithdrawing == false {
                    showError = true
                }
            }
        }
    }

    // MARK: - Balance Header
    private var balanceHeader: some View {
        VStack(spacing: 8) {
            Text("可提现余额")
                .font(.caption)
                .foregroundColor(.textSecondary)
            Text(String(format: "%.4f", merchantVM.balance))
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .foregroundColor(.gold)
            Text("USDT")
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.bgCard)
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }

    // MARK: - Withdrawal Form
    private var withdrawalForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("提现申请")
                .font(.headline)
                .foregroundColor(.textPrimary)

            // Amount Input
            VStack(alignment: .leading, spacing: 6) {
                Text("提现金额 (USDT)")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                HStack {
                    TextField("输入金额", text: $amount)
                        .keyboardType(.decimalPad)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.textPrimary)
                    Button("全部") {
                        amount = String(format: "%.4f", merchantVM.balance)
                    }
                    .font(.caption)
                    .foregroundColor(.gold)
                }
                .padding(12)
                .background(Color.bgPrimary)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
                )
            }

            // Wallet Selection
            VStack(alignment: .leading, spacing: 6) {
                Text("提现钱包地址")
                    .font(.caption)
                    .foregroundColor(.textSecondary)

                if enabledWallets.isEmpty {
                    Text("暂无可用钱包，请先在钱包页面添加")
                        .font(.caption)
                        .foregroundColor(.statusWarning)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.bgPrimary)
                        .cornerRadius(8)
                } else {
                    ForEach(enabledWallets) { wallet in
                        Button(action: { selectedWallet = wallet.token }) {
                            HStack {
                                Image(systemName: selectedWallet == wallet.token ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedWallet == wallet.token ? .gold : .textSecondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(wallet.truncatedAddress)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.textPrimary)
                                    if let chain = wallet.chain {
                                        Text(chain)
                                            .font(.system(size: 10))
                                            .foregroundColor(.textSecondary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(selectedWallet == wallet.token ? Color.gold.opacity(0.1) : Color.bgPrimary)
                            .cornerRadius(8)
                        }
                    }
                }
            }

            // Submit Button
            Button(action: submitWithdrawal) {
                HStack {
                    if merchantVM.isWithdrawing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .bgPrimary))
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                        Text("提交提现申请")
                    }
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.bgPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canSubmit ? Color.gold : Color.textSecondary.opacity(0.5))
                .cornerRadius(12)
            }
            .disabled(!canSubmit || merchantVM.isWithdrawing)
        }
        .padding(16)
        .background(Color.bgCard)
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }

    // MARK: - Withdrawal History
    private var withdrawalHistory: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("提现记录")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                Spacer()
                Button(action: { merchantVM.loadWithdrawals() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                        .foregroundColor(.gold)
                }
            }

            if merchantVM.withdrawals.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 28))
                        .foregroundColor(.textSecondary)
                    Text("暂无提现记录")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(30)
            } else {
                ForEach(merchantVM.withdrawals) { withdrawal in
                    withdrawalRow(withdrawal)
                }
            }
        }
        .padding(16)
        .background(Color.bgCard)
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }

    // MARK: - Withdrawal Row
    private func withdrawalRow(_ w: MerchantWithdrawal) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(w.withdrawNo)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                Spacer()
                withdrawalStatusBadge(w.status)
            }
            HStack {
                Text(String(format: "%.4f USDT", w.amount))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.gold)
                Spacer()
                if let chain = w.chain {
                    Text(chain)
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.statusInfo.opacity(0.2))
                        .foregroundColor(.statusInfo)
                        .cornerRadius(4)
                }
            }
            if let reason = w.rejectReason, !reason.isEmpty {
                Text("拒绝原因: \(reason)")
                    .font(.system(size: 10))
                    .foregroundColor(.statusError)
            }
            if let time = w.createdAt {
                Text(time)
                    .font(.system(size: 10))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(10)
        .background(Color.bgPrimary)
        .cornerRadius(8)
    }

    // MARK: - Status Badge
    private func withdrawalStatusBadge(_ status: Int) -> some View {
        let (text, color): (String, Color) = {
            switch status {
            case 1: return ("待审核", .statusWarning)
            case 2: return ("转账中", .statusInfo)
            case 3: return ("已完成", .statusSuccess)
            case 4: return ("已拒绝", .statusError)
            default: return ("未知", .textSecondary)
            }
        }()

        return Text(text)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(4)
    }

    // MARK: - Helpers
    private var canSubmit: Bool {
        guard let amt = Double(amount), amt > 0, amt <= merchantVM.balance else { return false }
        return !selectedWallet.isEmpty
    }

    private func submitWithdrawal() {
        guard let amt = Double(amount) else { return }
        merchantVM.createWithdrawal(amount: amt, toWallet: selectedWallet)
    }
}
