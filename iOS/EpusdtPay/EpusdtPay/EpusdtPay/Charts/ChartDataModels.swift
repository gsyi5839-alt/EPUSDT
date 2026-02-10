//
//  ChartDataModels.swift
//  EpusdtPay
//
//  Chart data models for displaying crypto price charts
//

import Foundation

// MARK: - Chart Data Point
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Double
}

// MARK: - Candlestick Data
struct CandlestickData: Identifiable {
    let id = UUID()
    let timestamp: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
}

// MARK: - Chart Time Range
enum ChartTimeRange: String, CaseIterable {
    case hour1 = "1H"
    case hour4 = "4H"
    case day1 = "1D"
    case week1 = "1W"
    case month1 = "1M"

    var displayName: String {
        return self.rawValue
    }
}
