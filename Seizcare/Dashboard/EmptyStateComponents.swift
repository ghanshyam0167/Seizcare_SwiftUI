//
//  EmptyStateComponents.swift
//  Seizcare
//

import SwiftUI

/// An overlay to be placed on top of charts that have no data.
struct EmptyChartOverlay: View {
    var title: String = "No data available yet"
    var subtitle: String = "Start tracking to see insights"
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Color.dashSecondary.opacity(0.6))
                .padding(.bottom, 4)
            
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.dashLabel)
            
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(Color.dashSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dashCard.opacity(0.85)) // slight blur/fade over grid
    }
}

/// A modifier to easily overlay the empty state on a chart
struct EmptyChartModifier: ViewModifier {
    let isEmpty: Bool
    let title: String
    let subtitle: String
    
    func body(content: Content) -> some View {
        content
            .overlay {
                if isEmpty {
                    EmptyChartOverlay(title: title, subtitle: subtitle)
                }
            }
    }
}

extension View {
    func emptyChartOverlay(isEmpty: Bool, title: String = "No data available yet", subtitle: String = "Start tracking to see insights") -> some View {
        modifier(EmptyChartModifier(isEmpty: isEmpty, title: title, subtitle: subtitle))
    }
}
