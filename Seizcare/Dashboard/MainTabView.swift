//
//  MainTabView.swift
//  Seizcare
//

import SwiftUI

enum Tab {
    case dashboard
    case records
}


struct MainTabView: View {
    @ObservedObject var authVM: AuthViewModel
    @StateObject private var recordsVM = RecordsViewModel()
    
    @State private var selectedTab: Tab = .records

    var body: some View {
        NavigationStack {
            Group {
                switch selectedTab {
                case .dashboard:
                    DashboardView()
                        .environmentObject(recordsVM)
                case .records:
                    RecordsListView()
                        .environmentObject(recordsVM)
                }
            }
            // By attaching toolbar here, it correctly surfaces in the NavigationStack
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    
                    Button {
                        withAnimation {
                            selectedTab = .dashboard
                        }
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "chart.xyaxis.line")
                                .font(.system(size: 18))
                            Text("Dashboard")
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .foregroundStyle(selectedTab == .dashboard ? .primary : .secondary)

                    Button {
                        withAnimation {
                            selectedTab = .records
                        }
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "list.bullet.rectangle")
                                .font(.system(size: 18))
                            Text("Records")
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .foregroundStyle(selectedTab == .records ? .primary : .secondary)

                    Spacer()

                    Button {
                        recordsVM.showAddRecord = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.dashSeizure)
                    }
                }
            }
            .toolbarBackground(.visible, for: .bottomBar)
            .toolbarBackground(.ultraThinMaterial, for: .bottomBar)
        }
        .tint(Color.dashSeizure)
        .sheet(isPresented: $recordsVM.showAddRecord) {
            AddEditRecordView(mode: .add)
                .environmentObject(recordsVM)
        }
    }
}

#Preview {
    MainTabView(authVM: AuthViewModel())
}
