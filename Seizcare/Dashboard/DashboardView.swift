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
    @Binding var selectedTab: Tab
    @EnvironmentObject var vm: RecordsViewModel
    @State private var activeChart: ActiveChart?
    @State private var frequencyRange: TimeFrameRange = .weekly

    private var records: [SeizureRecord] { vm.records }
    private let sleep   = MockDashboardData.sleepRecords

    private var recentRecord: SeizureRecord? { records.first }
    private var avgSleep7Days: Double {
        let recent = sleep.prefix(7)
        guard !recent.isEmpty else { return 0 }
        return recent.reduce(0) { $0 + $1.hours } / Double(recent.count)
    }

    // Seizure control: inverse of seizure frequency relative to max expected (3/week)
    private var controlPercent: Double {
        let thisMonthCount = records.filter {
            Calendar.current.isDate($0.startTime, equalTo: Date(), toGranularity: .month)
        }.count
        return max(0, 1.0 - Double(thisMonthCount) / 12.0)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.dashBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // ── Header ──────────────────────────────
                    DashboardHeaderView()

                    // ── Hero Card ───────────────────────────
                    HeroCardView(
                        records: records,
                        sleepRecords: sleep,
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
                            Button(action: { activeChart = .seizureFrequency }) {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .center) {
                                        Text("Event Count")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(Color.dashLabel)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(Color.dashSecondary)
                                            .padding(6)
                                            .background(Circle().fill(Color.dashSecondary.opacity(0.15)))
                                    }
                                    
                                    SeizureFrequencyMiniChart(records: records, range: frequencyRange)
                                        .padding(.top, 4)
                                }
                                .padding(14)
                                .background(Color.dashCard)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(Color.dashSeizure.opacity(0.15), lineWidth: 1)
                                )
                            }
                            .buttonStyle(ScaleButtonStyle())

                            // 2. SLEEP CARD
                            GraphCard(
                                title: "Sleep",
                                color: .dashSleep
                            ) {
                                SleepVsSeizuresMiniChart(records: records, sleep: sleep)
                            } onTap: {
                                activeChart = .sleepVsSeizures
                            }
                        }
                    }
                    
                    // ── Recent Records ───────────────────────
                    RecentRecordsView(records: records) {
                        withAnimation {
                            selectedTab = .records
                        }
                    }

                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }


        }
        .fullScreenCover(item: $activeChart) { chart in
            switch chart {
            case .seizureFrequency:
                SeizureFrequencyChartView(records: records, initialRange: frequencyRange)
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
    @EnvironmentObject var authVM: AuthViewModel

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
            NavigationLink(destination: SettingsView(vm: authVM)) {
                Circle()
                    .fill(Color.dashCardElevated)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.dashSecondary)
                    )
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Graph Card

private struct GraphCard<Content: View>: View {
    let title: String
    let color: Color
    @ViewBuilder let chart: Content
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.dashLabel)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.dashSecondary)
                        .padding(6)
                        .background(Circle().fill(Color.dashSecondary.opacity(0.15)))
                }
                
                chart
                    .frame(height: 125)
                    .clipped()
                    .padding(.top, 4)
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




