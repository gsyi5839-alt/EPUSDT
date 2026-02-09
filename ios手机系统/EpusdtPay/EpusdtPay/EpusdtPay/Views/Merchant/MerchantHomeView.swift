//
//  MerchantHomeView.swift
//  EpusdtPay
//
//  Dashboard with stats and data lists
//

import SwiftUI

struct MerchantHomeView: View {
    @EnvironmentObject var merchantVM: MerchantViewModel
    @State private var selectedSegment = 0

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // MARK: - Welcome Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("商户中心")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.textPrimary)
                            Text("今日数据概览")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                        Spacer()
                        Button(action: { merchantVM.loadDashboard() }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16))
                                .foregroundColor(.gold)
                                .padding(10)
                                .background(Color.bgCard)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // MARK: - Stats Grid (2x2)
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        StatCard(
                            icon: "yensign.circle.fill",
                            title: "今日营收",
                            value: String(format: "¥%.2f", merchantVM.todayRevenueCny),
                            color: .gold
                        )
                        StatCard(
                            icon: "checkmark.shield.fill",
                            title: "活跃授权",
                            value: "\(merchantVM.activeAuthCount)",
                            color: .statusSuccess
                        )
                        StatCard(
                            icon: "arrow.down.circle.fill",
                            title: "今日扣款",
                            value: "\(merchantVM.todayDeductionCount)",
                            color: .statusInfo
                        )
                        StatCard(
                            icon: "bitcoinsign.circle.fill",
                            title: "总收入 USDT",
                            value: String(format: "%.2f", merchantVM.totalRevenueUsdt),
                            color: .gold
                        )
                    }
                    .padding(.horizontal, 16)

                    // MARK: - Quick Actions
                    HStack(spacing: 12) {
                        QuickActionButton(icon: "qrcode", title: "收款码", color: .gold)
                        QuickActionButton(icon: "arrow.left.arrow.right", title: "转账", color: .statusInfo)
                        QuickActionButton(icon: "clock.arrow.circlepath", title: "历史", color: .statusSuccess)
                        QuickActionButton(icon: "gearshape", title: "设置", color: .textSecondary)
                    }
                    .padding(.horizontal, 16)

                    // MARK: - Segment Picker
                    Picker("", selection: $selectedSegment) {
                        Text("订单").tag(0)
                        Text("授权").tag(1)
                        Text("扣款").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)

                    // MARK: - List Content
                    if merchantVM.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .gold))
                            .padding(40)
                    } else if let error = merchantVM.errorMessage {
                        ErrorBanner(message: error, onDismiss: { merchantVM.errorMessage = nil })
                            .padding(.horizontal, 16)
                    } else {
                        switch selectedSegment {
                        case 0:
                            ordersSection
                        case 1:
                            authorizationsSection
                        case 2:
                            deductionsSection
                        default:
                            EmptyView()
                        }
                    }
                }
                .padding(.vertical, 16)
            }
            .navigationBarHidden(true)
            .darkBackground()
            .onAppear { merchantVM.loadDashboard() }
            .refreshable { merchantVM.loadDashboard() }
        }
    }

    // MARK: - Orders Section
    private var ordersSection: some View {
        VStack(spacing: 8) {
            if merchantVM.orders.isEmpty {
                emptyState("暂无订单数据")
            } else {
                ForEach(merchantVM.orders) { order in
                    OrderRowView(order: order)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Authorizations Section
    private var authorizationsSection: some View {
        VStack(spacing: 8) {
            if merchantVM.authorizations.isEmpty {
                emptyState("暂无授权数据")
            } else {
                ForEach(merchantVM.authorizations) { auth in
                    AuthorizationRowView(authorization: auth)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Deductions Section
    private var deductionsSection: some View {
        VStack(spacing: 8) {
            if merchantVM.deductions.isEmpty {
                emptyState("暂无扣款数据")
            } else {
                ForEach(merchantVM.deductions) { deduct in
                    DeductionRowView(deduction: deduct)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func emptyState(_ text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundColor(.textSecondary)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

// MARK: - Quick Action Button
struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Order Row View
struct OrderRowView: View {
    let order: Order

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(order.tradeId)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                Spacer()
                StatusBadge(orderStatus: order.status)
            }
            HStack {
                HStack(spacing: 4) {
                    Text("金额:")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    Text(String(format: "%.4f USDT", order.actualAmount))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.gold)
                }
                Spacer()
                if let chain = order.chain {
                    ChainBadge(chain: chain)
                }
            }
            if let time = order.createdAt {
                Text(time)
                    .font(.system(size: 10))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(12)
        .background(Color.bgCard)
        .cornerRadius(8)
    }
}

// MARK: - Authorization Row View
struct AuthorizationRowView: View {
    let authorization: KtvAuthorization

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(authorization.authNo)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                Spacer()
                StatusBadge(authStatus: authorization.status)
            }
            HStack {
                if let tableNo = authorization.tableNo, !tableNo.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "tablecells")
                            .font(.system(size: 10))
                        Text(tableNo)
                            .font(.caption)
                    }
                    .foregroundColor(.textSecondary)
                }
                Spacer()
                Text(String(format: "%.2f USDT", authorization.authorizedUsdt))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.gold)
            }
            HStack {
                if let name = authorization.customerName, !name.isEmpty {
                    Text(name)
                        .font(.system(size: 10))
                        .foregroundColor(.textSecondary)
                }
                Spacer()
                if authorization.status == 2 {
                    Text("剩余: \(String(format: "%.2f", authorization.remainingUsdt))")
                        .font(.system(size: 10))
                        .foregroundColor(.statusSuccess)
                }
            }
        }
        .padding(12)
        .background(Color.bgCard)
        .cornerRadius(8)
    }
}

// MARK: - Deduction Row View
struct DeductionRowView: View {
    let deduction: KtvDeduction

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(deduction.deductNo)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                Spacer()
                StatusBadge(deductStatus: deduction.status)
            }
            HStack {
                HStack(spacing: 4) {
                    Text("¥")
                        .font(.caption)
                        .foregroundColor(.statusWarning)
                    Text(String(format: "%.2f", deduction.amountCny))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.statusWarning)
                }
                Text("→")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                HStack(spacing: 4) {
                    Text(String(format: "%.4f", deduction.amountUsdt))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.gold)
                    Text("USDT")
                        .font(.system(size: 10))
                        .foregroundColor(.gold)
                }
                Spacer()
            }
            if let product = deduction.productInfo, !product.isEmpty {
                Text(product)
                    .font(.system(size: 10))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(12)
        .background(Color.bgCard)
        .cornerRadius(8)
    }
}
