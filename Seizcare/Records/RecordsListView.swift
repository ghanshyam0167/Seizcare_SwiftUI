//
//  RecordsListView.swift
//  Seizcare
//
//  Main "Records" screen: grouped list + search + filter + report.

import SwiftUI

struct RecordsListView: View {
    @EnvironmentObject var vm: RecordsViewModel
    @EnvironmentObject var languageManager: LanguageManager
    @State private var selectedRecord: SeizureRecord? = nil
    @State private var selectedReportDuration: ReportDuration? = nil

    var body: some View {
        ZStack {
            Color.dashBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Grouping segmented control
                groupingPicker

                // Active filter chips
                if vm.filter.isActive {
                    activeFilterChips
                }

                // Main content
                mainContent
            }
            
            if vm.isLoading {
                Color.black.opacity(0.1).ignoresSafeArea()
                LoadingView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .navigationTitle("records_title")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $vm.searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: "search_records")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                // Report button
                Button {
                    vm.showReportOptions = true
                } label: {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundStyle(Color.dashLabel)

                // Filter button
                Button {
                    vm.showFilterSheet = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 15, weight: .medium))
                        if vm.filter.isActive {
                            Circle()
                                .fill(Color.dashSeizure)
                                .frame(width: 7, height: 7)
                                .offset(x: 3, y: -3)
                        }
                    }
                }
                .foregroundStyle(vm.filter.isActive ? Color.dashSeizure : Color.dashLabel)
            }
        }
        .navigationDestination(item: $selectedRecord) { record in
            RecordDetailView(record: record)
                .environmentObject(vm)
        }
        .sheet(isPresented: $vm.showFilterSheet) {
            FilterSheetView(filter: $vm.filter) {
                // onApply — filter is already bound
            } onReset: {
                vm.filter.reset()
            }
        }
        .sheet(isPresented: $vm.showReportOptions) {
            ReportOptionsSheet { duration in
                selectedReportDuration = duration
            }
            .environmentObject(languageManager)
        }
        .sheet(item: $selectedReportDuration) { duration in
            let cutoff = Calendar.current.date(byAdding: .day, value: -duration.days, to: Date()) ?? Date()
            let reportRecords = vm.records.filter { $0.startTime >= cutoff }
            ReportView(records: reportRecords, duration: duration)
                .environmentObject(languageManager)
        }
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { _ in vm.errorMessage = nil }
        )) {
            Button("ok", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    // MARK: - Grouping Picker

    private var groupingPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RecordGrouping.allCases) { mode in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            vm.grouping = mode
                        }
                    } label: {
                        Text(LocalizedStringKey(mode.rawValue.lowercased()))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(vm.grouping == mode ? .white : Color.dashSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                vm.grouping == mode
                                    ? Color.dashSeizure
                                    : Color.dashCard
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Active Filter Chips

    private var activeFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(vm.filter.activeChips, id: \.self) { chip in
                    Button {
                        withAnimation { vm.filter.removeChip(chip) }
                    } label: {
                        HStack(spacing: 5) {
                            Text(chip.lowercased().replacingOccurrences(of: " ", with: "_").localized)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.dashSleep)
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.dashSleep.opacity(0.7))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.dashSleep.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.dashSleep.opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(ScaleButtonStyle())
                }

                Button {
                    withAnimation { vm.filter.reset() }
                } label: {
                    Text("clear_all".localized)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.dashSeizure)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.dashSeizure.opacity(0.10))
                        .clipShape(Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        let groups = vm.groupedRecords

        if vm.isLoading {
            Spacer()
        } else if vm.records.isEmpty {
            ScrollView {
                RecordsEmptyState()
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
            }
        } else if groups.isEmpty {
            // No results from search/filter
            ScrollView {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.dashTertiary)
                    Text("no_results_found")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.dashSecondary)
                    if vm.filter.isActive {
                        Button {
                            withAnimation { vm.filter.reset() }
                        } label: {
                            Text("clear_filters")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.dashSeizure)
                                .clipShape(Capsule())
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 100)
            }
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0, pinnedViews: []) {
                    ForEach(groups, id: \.header) { group in
                        MonthSectionHeader(title: group.header)
                            .padding(.horizontal, 16)

                        VStack(spacing: 0) {
                            ForEach(Array(group.records.enumerated()), id: \.element.id) { index, record in
                                Button {
                                    selectedRecord = record
                                } label: {
                                    RecordCard(record: record)
                                }
                                .buttonStyle(ScaleButtonStyle())

                                if index < group.records.count - 1 {
                                    Divider()
                                        .padding(.leading, 16)
                                }
                            }
                        }
                        .background(Color.dashCard)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.black.opacity(0.02), radius: 8, y: 4)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }
                .padding(.bottom, 64)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        RecordsListView()
            .environmentObject(RecordsViewModel())
    }
}
