//
//  RecordsListView.swift
//  Seizcare
//
//  Main "Records" screen: grouped list + bottom search bar.

import SwiftUI

struct RecordsListView: View {
    @EnvironmentObject var vm: RecordsViewModel

    // For navigation to detail
    @State private var selectedRecord: SeizureRecord? = nil

    var body: some View {
        ZStack {
            Color.dashBg.ignoresSafeArea()

            // ── Content ──────────────────────────────────
            if vm.records.isEmpty {
                // Empty state
                ScrollView {
                    RecordsEmptyState()
                        .padding(.horizontal, 20)
                        .padding(.top, 60)
                }
            } else if vm.filteredRecords.isEmpty && !vm.searchQuery.isEmpty {
                // No search results
                ScrollView {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.dashTertiary)
                        Text("No results for \"\(vm.searchQuery)\"")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.dashSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                }
            } else {
                // Records list grouped by month
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0, pinnedViews: []) {
                        ForEach(vm.groupedRecords, id: \.month) { group in
                            // Month header
                            MonthSectionHeader(title: group.month)
                                .padding(.horizontal, 16)

                            // Cards for this month
                            VStack(spacing: 8) {
                                ForEach(group.records) { record in
                                    Button {
                                        selectedRecord = record
                                    } label: {
                                        RecordCard(record: record)
                                            .padding(.horizontal, 16)
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                            }
                            .padding(.bottom, 8)
                        }
                    }
                    .padding(.bottom, 64)
                }
            }
        }
        .navigationTitle("Records")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $vm.searchQuery, prompt: "Search records")
        // Navigate to detail
        .navigationDestination(item: $selectedRecord) { record in
            RecordDetailView(record: record)
                .environmentObject(vm)
        }
    }
}

// MARK: - Preview

#Preview {
    RecordsListView()
        .environmentObject(RecordsViewModel())
}
