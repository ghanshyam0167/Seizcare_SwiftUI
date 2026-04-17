//
//  DashboardView.swift
//  Seizcare
//

import SwiftUI
import Charts

// MARK: - Active Chart Enum

enum ActiveChart: Identifiable {
    case seizureFrequency
    case sleepVsSeizures
    case streak
    case triggerCorrelation
    case heartRateTimeline(SeizureRecord)

    var id: String {
        switch self {
        case .seizureFrequency:         return "freq"
        case .sleepVsSeizures:          return "sleep"
        case .streak:                   return "streak"
        case .triggerCorrelation:       return "trigger"
        case .heartRateTimeline(let r): return "hr-\(r.id.uuidString)"
        }
    }
}

// MARK: - Dashboard View

struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel
    
    init(recordsVM: RecordsViewModel, healthVM: HealthViewModel) {
        _viewModel = StateObject(wrappedValue: DashboardViewModel(recordsVM: recordsVM, healthVM: healthVM))
    }

    private var records: [SeizureRecord] { viewModel.records }
    private var sleep: [SleepData] { viewModel.sleepData }
    private var avgSleep7Days: Double { viewModel.avgSleep7Days }
    private var controlPercent: Double { viewModel.controlPercent }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.dashBg.ignoresSafeArea()

            if viewModel.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(Color.dashPurple)
                    Text("Fetching health data...")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.dashSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // ── Header ──────────────────────────────
                        DashboardHeaderView()

                        // ── Hero Card ───────────────────────────
                        HeroCardView(
                            records: records,
                            sleepHours: avgSleep7Days,
                            heartRate: viewModel.currentHeartRate,
                            onSendAlert: { /* TODO: implement alert */ }
                        )

                        // ── Analysis Cards ───────────────────────
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Analysis", icon: "chart.xyaxis.line")
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ], spacing: 12) {
                                
                                // 1. FREQUENCY CARD
                                GraphCard(
                                    title: "Frequency",
                                    subtitle: "Seizure count over time",
                                    color: .dashSeizure
                                ) {
                                    SeizureFrequencyMiniChart(records: records, range: viewModel.frequencyRange)
                                } onTap: {
                                    viewModel.activeChart = .seizureFrequency
                                }

                                // 2. SLEEP CARD
                                GraphCard(
                                    title: "Sleep",
                                    subtitle: "Sleep vs events",
                                    color: .dashSleep
                                ) {
                                    SleepVsSeizuresMiniChart(records: records, sleep: sleep)
                                } onTap: {
                                    viewModel.activeChart = .sleepVsSeizures
                                }

                                // 3. TRIGGERS CARD
                                GraphCard(
                                    title: "Triggers",
                                    subtitle: "Top correlation",
                                    color: Color(red: 1.0, green: 0.6, blue: 0.2)
                                ) {
                                    TriggerCorrelationMiniChart(records: records)
                                } onTap: {
                                    viewModel.activeChart = .triggerCorrelation
                                }
                                
                                // 4. STREAK CARD
                                GraphCard(
                                    title: "Streak",
                                    subtitle: "Seizure-free days",
                                    color: Color.dashGreen
                                ) {
                                    SeizureStreakMiniChart(records: records)
                                } onTap: {
                                    viewModel.activeChart = .streak
                                }
                            }
                        }
                        
                        // ── Recent Records ───────────────────────
                        RecentRecordsView(records: records)
                        
                        if !viewModel.healthVM.guidanceText.isEmpty {
                            Text(viewModel.healthVM.guidanceText)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.dashSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                                .padding(.top, 4)
                        }

                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
        }
        .fullScreenCover(item: $viewModel.activeChart) { chart in
            switch chart {
            case .seizureFrequency:
                SeizureFrequencyChartView(records: records, initialRange: viewModel.frequencyRange)
            case .sleepVsSeizures:
                SleepVsSeizuresChartView(records: records, sleep: sleep)
            case .streak:
                SeizureStreakChartView(records: records)
            case .triggerCorrelation:
                TriggerCorrelationChartView(records: records)
            case .heartRateTimeline(let rec):
                HeartRateTimelineChartView(record: rec)
            }
        }
    }
}

// MARK: - Header

private struct DashboardHeaderView: View {
    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: Date())
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Summary")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.dashLabel)
                Text(dateString)
                    .font(.subheadline)
                    .foregroundStyle(Color.dashSecondary)
            }
            Spacer()
            Circle()
                .fill(Color.dashCardElevated)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.dashSecondary)
                )
        }
        .padding(.top, 8)
    }
}

// MARK: - Graph Card

private struct GraphCard<Content: View>: View {
    let title: String
    let subtitle: String
    let color: Color
    @ViewBuilder let chart: Content
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.dashLabel)
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(Color.dashSecondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(color.opacity(0.8))
                }
                chart
                    .frame(height: 60)
                    .clipped()
            }
            .padding(14)
            .background(Color.dashCard)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(color.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}




