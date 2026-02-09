//
//  MyAuthorizationsView.swift
//  EpusdtPay
//
//  List of customer's authorizations
//

import SwiftUI
import Combine

struct MyAuthorizationsView: View {
    @StateObject private var viewModel = MyAuthorizationsViewModel()
    @State private var selectedFilter: AuthFilter = .all

    enum AuthFilter: String, CaseIterable {
        case all = "All"
        case active = "Active"
        case expired = "Expired"
    }

    var filteredAuthorizations: [KtvAuthorization] {
        switch selectedFilter {
        case .all:
            return viewModel.authorizations
        case .active:
            return viewModel.authorizations.filter { $0.status == 2 }
        case .expired:
            return viewModel.authorizations.filter { $0.status == 3 || $0.status == 4 }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Filter Picker
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(AuthFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 10)

                // Summary Stats
                HStack(spacing: 12) {
                    SmallStatCard(
                        title: "Active",
                        value: "\(viewModel.activeCount)",
                        color: .statusSuccess
                    )

                    SmallStatCard(
                        title: "Total Amount",
                        value: String(format: "%.2f", viewModel.totalAmount),
                        color: .gold
                    )

                    SmallStatCard(
                        title: "Used",
                        value: String(format: "%.2f", viewModel.totalUsed),
                        color: .statusWarning
                    )
                }
                .padding(.horizontal, 16)

                // Error Banner
                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error, onDismiss: {
                        viewModel.errorMessage = nil
                    })
                    .padding(.horizontal, 16)
                }

                // Authorizations List
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .gold))
                        .padding(.top, 40)
                } else if filteredAuthorizations.isEmpty {
                    EmptyStateView(
                        icon: "doc.text.magnifyingglass",
                        title: "No Authorizations",
                        message: selectedFilter == .all ?
                            "You haven't authorized any payments yet" :
                            "No \(selectedFilter.rawValue.lowercased()) authorizations found"
                    )
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredAuthorizations) { auth in
                            NavigationLink(destination: AuthorizationDetailView(authorization: auth)) {
                                AuthorizationCardView(authorization: auth)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 30)
        }
        .navigationTitle("My Authorizations")
        .navigationBarTitleDisplayMode(.inline)
        .darkBackground()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    viewModel.loadAuthorizations()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.gold)
                }
            }
        }
        .onAppear {
            viewModel.loadAuthorizations()
        }
    }
}

// MARK: - Small Stat Card
struct SmallStatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)

            Text(title)
                .font(.caption2)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.bgCard)
        .cornerRadius(10)
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(.textSecondary)

            Text(title)
                .font(.headline)
                .foregroundColor(.textPrimary)

            Text(message)
                .font(.caption)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Authorization Detail View
struct AuthorizationDetailView: View {
    let authorization: KtvAuthorization
    @StateObject private var viewModel = AuthDetailViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Card
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Authorization Details")
                            .font(.headline)
                            .foregroundColor(.textPrimary)
                        Spacer()
                        StatusBadge(authStatus: authorization.status)
                    }

                    Divider().background(Color.textSecondary.opacity(0.3))

                    InfoRow(label: "Auth No.", value: authorization.authNo, valueColor: .gold)

                    if let password = authorization.password {
                        InfoRow(label: "Password", value: password, valueColor: .statusWarning)
                    }

                    InfoRow(label: "Authorized", value: String(format: "%.4f USDT", authorization.authorizedUsdt), valueColor: .gold)
                    InfoRow(label: "Used", value: String(format: "%.4f USDT", authorization.usedUsdt), valueColor: .statusWarning)
                    InfoRow(label: "Remaining", value: String(format: "%.4f USDT", authorization.remainingUsdt), valueColor: .statusSuccess)

                    if let table = authorization.tableNo {
                        InfoRow(label: "Table No.", value: table)
                    }

                    if let name = authorization.customerName {
                        InfoRow(label: "Customer", value: name)
                    }

                    if let chain = authorization.chain {
                        HStack {
                            Text("Chain")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                            Spacer()
                            ChainBadge(chain: chain)
                        }
                    }

                    if let wallet = authorization.customerWallet {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Customer Wallet")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                            Text(wallet)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.textPrimary)
                        }
                    }

                    if let merchantWallet = authorization.merchantWallet {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Merchant Wallet")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                            Text(merchantWallet)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.textPrimary)
                        }
                    }

                    if let txHash = authorization.txHash {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Transaction Hash")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                            Text(txHash)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.statusInfo)
                                .lineLimit(2)
                        }
                    }
                }
                .padding(16)
                .background(Color.bgCard)
                .cornerRadius(12)

                // Deduction History
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Deduction History")
                            .font(.headline)
                            .foregroundColor(.textPrimary)
                        Spacer()
                        Button(action: {
                            if let password = authorization.password {
                                viewModel.loadHistory(password: password)
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                                .foregroundColor(.gold)
                        }
                    }

                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .gold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    } else if viewModel.deductions.isEmpty {
                        Text("No deductions yet")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    } else {
                        ForEach(viewModel.deductions) { deduction in
                            CustomerDeductionRowView(deduction: deduction)
                        }
                    }
                }
                .padding(16)
                .background(Color.bgCard)
                .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .darkBackground()
        .onAppear {
            if let password = authorization.password {
                viewModel.loadHistory(password: password)
            }
        }
    }
}

// MARK: - Customer Deduction Row View
struct CustomerDeductionRowView: View {
    let deduction: KtvDeduction

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Deduct #\(String(deduction.deductNo.suffix(8)))")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.gold)

                    if let productInfo = deduction.productInfo {
                        Text(productInfo)
                            .font(.caption2)
                            .foregroundColor(.textSecondary)
                    }
                }

                Spacer()

                StatusBadge(deductStatus: deduction.status)
            }

            Divider().background(Color.textSecondary.opacity(0.2))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Amount")
                        .font(.caption2)
                        .foregroundColor(.textSecondary)
                    Text(String(format: "¥%.2f (%.4f USDT)", deduction.amountCny, deduction.amountUsdt))
                        .font(.caption)
                        .foregroundColor(.textPrimary)
                }

                Spacer()

                if let operatorId = deduction.operatorId {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Operator")
                            .font(.caption2)
                            .foregroundColor(.textSecondary)
                        Text(operatorId)
                            .font(.caption)
                            .foregroundColor(.textPrimary)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.bgInput)
        .cornerRadius(8)
    }
}

// MARK: - My Authorizations ViewModel
class MyAuthorizationsViewModel: ObservableObject {
    @Published var authorizations: [KtvAuthorization] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiService = APIService.shared

    var activeCount: Int {
        authorizations.filter { $0.status == 2 }.count
    }

    var totalAmount: Double {
        authorizations.reduce(0) { $0 + $1.authorizedUsdt }
    }

    var totalUsed: Double {
        authorizations.reduce(0) { $0 + $1.usedUsdt }
    }

    func loadAuthorizations() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let auths = try await apiService.fetchAuthorizations()
                await MainActor.run {
                    self.authorizations = auths
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Auth Detail ViewModel
class AuthDetailViewModel: ObservableObject {
    @Published var deductions: [KtvDeduction] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiService = APIService.shared

    func loadHistory(password: String) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let deducts = try await apiService.getDeductionHistory(password: password)
                await MainActor.run {
                    self.deductions = deducts
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
