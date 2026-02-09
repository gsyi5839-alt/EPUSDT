//
//  CandlestickChartView.swift
//  EpusdtPay
//
//  Candlestick chart for crypto trading data
//

import SwiftUI

struct CandlestickChartView: View {
    let data: [CandlestickData]
    var bullColor: Color = .green
    var bearColor: Color = .red

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(Array(data.enumerated()), id: \.element.id) { index, candle in
                    candlestickShape(
                        candle: candle,
                        index: index,
                        geometry: geometry
                    )
                }
            }
        }
        .frame(height: 250)
    }

    private func candlestickShape(candle: CandlestickData, index: Int, geometry: GeometryProxy) -> some View {
        let maxValue = data.map { max($0.high, $0.open, $0.close) }.max() ?? 1
        let minValue = data.map { min($0.low, $0.open, $0.close) }.min() ?? 0
        let valueRange = maxValue - minValue

        let stepX = geometry.size.width / CGFloat(data.count)
        let candleWidth = stepX * 0.6

        let x = CGFloat(index) * stepX + stepX / 2
        let highY = geometry.size.height - (CGFloat((candle.high - minValue) / valueRange) * geometry.size.height)
        let lowY = geometry.size.height - (CGFloat((candle.low - minValue) / valueRange) * geometry.size.height)
        let openY = geometry.size.height - (CGFloat((candle.open - minValue) / valueRange) * geometry.size.height)
        let closeY = geometry.size.height - (CGFloat((candle.close - minValue) / valueRange) * geometry.size.height)

        let isBullish = candle.close >= candle.open
        let color = isBullish ? bullColor : bearColor

        let bodyTop = min(openY, closeY)
        let bodyHeight = abs(openY - closeY)

        return ZStack {
            // Wick (high-low line)
            Rectangle()
                .fill(color)
                .frame(width: 1, height: lowY - highY)
                .position(x: x, y: highY + (lowY - highY) / 2)

            // Body (open-close rectangle)
            Rectangle()
                .fill(color)
                .frame(width: candleWidth, height: max(bodyHeight, 1))
                .position(x: x, y: bodyTop + bodyHeight / 2)
        }
    }
}
