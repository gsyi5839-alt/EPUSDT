//
//  PaymentViewModel.swift
//  EpusdtPay
//
//  Payment processing and transaction management
//

import Foundation
import Combine

class PaymentViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var currentPayment: Payment?
    @Published var isProcessing = false
    @Published var paymentStatus: PaymentStatus = .idle

    private let apiService = APIService.shared

    enum PaymentStatus {
        case idle
        case processing
        case completed
        case failed(String)
    }

    func createPayment(amount: Double, merchantWallet: String, chain: String) {
        let payment = Payment(
            id: UUID().uuidString,
            amount: amount,
            merchantWallet: merchantWallet,
            chain: chain,
            createdAt: Date()
        )
        currentPayment = payment
        paymentStatus = .processing

        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.paymentStatus = .completed
            let transaction = Transaction(
                id: UUID().uuidString,
                paymentId: payment.id,
                amount: amount,
                chain: chain,
                status: "completed",
                transactionHash: "0x" + String(format: "%064x", arc4random_uniform(0xFFFFFFFF)),
                createdAt: Date()
            )
            self.transactions.insert(transaction, at: 0)
        }
    }

    func fetchTransactionHistory() {
        isProcessing = true
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isProcessing = false
        }
    }
}
