//
//  ChartView.swift
//  en01
//
//  Created by AI Assistant on 2024/12/30.
//

import SwiftUI
import Charts

/// 图表视图组件
struct ChartView: View {
    let data: [ChartDataPoint]
    let title: String
    let color: Color
    let animate: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            if data.isEmpty {
                // 空数据状态
                VStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Text("暂无数据")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 图表内容
                Chart(data, id: \.date) { dataPoint in
                    LineMark(
                        x: .value("日期", dataPoint.date),
                        y: .value("数值", dataPoint.value)
                    )
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    AreaMark(
                        x: .value("日期", dataPoint.date),
                        y: .value("数值", dataPoint.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    PointMark(
                        x: .value("日期", dataPoint.date),
                        y: .value("数值", dataPoint.value)
                    )
                    .foregroundStyle(color)
                    .symbolSize(30)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: max(1, data.count / 5))) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .animation(animate ? .easeInOut(duration: 1.0) : .none, value: data)
            }
        }
    }
}

#Preview {
    let sampleData = [
        ChartDataPoint(date: Date().addingTimeInterval(-6*24*3600), value: 30, label: "30"),
        ChartDataPoint(date: Date().addingTimeInterval(-5*24*3600), value: 45, label: "45"),
        ChartDataPoint(date: Date().addingTimeInterval(-4*24*3600), value: 35, label: "35"),
        ChartDataPoint(date: Date().addingTimeInterval(-3*24*3600), value: 60, label: "60"),
        ChartDataPoint(date: Date().addingTimeInterval(-2*24*3600), value: 50, label: "50"),
        ChartDataPoint(date: Date().addingTimeInterval(-1*24*3600), value: 70, label: "70"),
        ChartDataPoint(date: Date(), value: 65, label: "65")
    ]
    
    ChartView(
        data: sampleData,
        title: "阅读时长趋势",
        color: .blue,
        animate: true
    )
    .frame(height: 200)
}