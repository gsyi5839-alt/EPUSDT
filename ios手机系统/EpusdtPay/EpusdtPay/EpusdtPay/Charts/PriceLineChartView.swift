//
//  PriceLineChartView.swift
//  EpusdtPay
//
//  Simple line chart for price display
//

import SwiftUI

struct PriceLineChartView: View {
    let dataPoints: [ChartDataPoint]
    var lineColor: Color = .green
    var showGradient: Bool = true

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if showGradient {
                    gradientFill(in: geometry)
                }
                linePath(in: geometry)
                    .stroke(lineColor, lineWidth: 2)
            }
        }
        .frame(height: 200)
    }

    private func linePath(in geometry: GeometryProxy) -> Path {
        guard !dataPoints.isEmpty else { return Path() }

        let maxValue = dataPoints.map { $0.value }.max() ?? 1
        let minValue = dataPoints.map { $0.value }.min() ?? 0
        let valueRange = maxValue - minValue

        var path = Path()
        let stepX = geometry.size.width / CGFloat(dataPoints.count - 1)

        for (index, point) in dataPoints.enumerated() {
            let x = CGFloat(index) * stepX
            let y = geometry.size.height - (CGFloat((point.value - minValue) / valueRange) * geometry.size.height)

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }

    private func gradientFill(in geometry: GeometryProxy) -> some View {
        guard !dataPoints.isEmpty else { return AnyView(EmptyView()) }

        let maxValue = dataPoints.map { $0.value }.max() ?? 1
        let minValue = dataPoints.map { $0.value }.min() ?? 0
        let valueRange = maxValue - minValue

        var path = Path()
        let stepX = geometry.size.width / CGFloat(dataPoints.count - 1)

        path.move(to: CGPoint(x: 0, y: geometry.size.height))

        for (index, point) in dataPoints.enumerated() {
            let x = CGFloat(index) * stepX
            let y = geometry.size.height - (CGFloat((point.value - minValue) / valueRange) * geometry.size.height)
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
        path.closeSubpath()

        return AnyView(
            path.fill(
                LinearGradient(
                    gradient: Gradient(colors: [lineColor.opacity(0.3), lineColor.opacity(0.0)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        )
    }
}
