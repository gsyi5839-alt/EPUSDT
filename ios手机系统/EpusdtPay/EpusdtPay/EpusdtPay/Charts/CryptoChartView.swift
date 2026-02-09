//
//  CryptoChartView.swift
//  EpusdtPay
//
//  Main crypto chart view with time range selector
//

import SwiftUI

struct CryptoChartView: View {
    @State private var selectedRange: ChartTimeRange = .day1
    @State private var dataPoints: [ChartDataPoint] = []

    var body: some View {
        VStack(spacing: 16) {
            // Chart
            if dataPoints.isEmpty {
                placeholderChart
            } else {
                PriceLineChartView(dataPoints: dataPoints, lineColor: .green)
            }

            // Time Range Selector
            HStack(spacing: 12) {
                ForEach(ChartTimeRange.allCases, id: \.self) { range in
                    Button(action: {
                        selectedRange = range
                        loadChartData(for: range)
                    }) {
                        Text(range.displayName)
                            .font(.caption)
                            .fontWeight(selectedRange == range ? .semibold : .regular)
                            .foregroundColor(selectedRange == range ? .white : .gray)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedRange == range ? Color.blue : Color.clear)
                            .cornerRadius(6)
                    }
                }
            }
        }
        .padding()
        .onAppear {
            loadChartData(for: selectedRange)
        }
    }

    private var placeholderChart: some View {
        VStack {
            Spacer()
            Text("加载图表数据...")
                .foregroundColor(.gray)
            Spacer()
        }
        .frame(height: 200)
    }

    private func loadChartData(for range: ChartTimeRange) {
        // TODO: Load real data from API
        // For now, generate sample data
        let count = 20
        let baseValue = 6.5
        dataPoints = (0..<count).map { index in
            let timestamp = Date().addingTimeInterval(-TimeInterval((count - index) * 3600))
            let value = baseValue + Double.random(in: -0.5...0.5)
            return ChartDataPoint(timestamp: timestamp, value: value)
        }
    }
}
