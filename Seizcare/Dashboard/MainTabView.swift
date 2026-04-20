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
    @StateObject private var healthVM = HealthViewModel()
    @StateObject private var avatarVM = AvatarViewModel.shared
    
    @State private var selectedTab: Tab = .dashboard
    @State private var tabDirection: ScreenNavDirection = .forward

    var body: some View {
        NavigationStack {
            ZStack {
                switch selectedTab {
                case .dashboard:
                    DashboardView(
                        selectedTab: $selectedTab,
                        recordsVM: recordsVM,
                        healthVM: healthVM
                    )
                    .environmentObject(authVM)
                    .environmentObject(avatarVM)
                    .transition(.screenSlide(tabDirection))
                case .records:
                    RecordsListView()
                        .environmentObject(recordsVM)
                        .environmentObject(avatarVM)
                        .transition(.screenSlide(tabDirection))
                }
            }
            .id(selectedTab)
            .animation(.easeInOut(duration: 0.30), value: selectedTab)
            // By attaching toolbar here, it correctly surfaces in the NavigationStack
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    
                    Button {
                        withAnimation {
                            tabDirection = .back
                            selectedTab = .dashboard
                        }
                    } label: {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 24))
                    }
                    .foregroundStyle(selectedTab == .dashboard ? Color.dashAccent : Color.secondary)

                    Button {
                        withAnimation {
                            tabDirection = .forward
                            selectedTab = .records
                        }
                    } label: {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 24))
                    }
                    .foregroundStyle(selectedTab == .records ? Color.dashAccent : Color.secondary)

                    Spacer()

                    Button {
                        recordsVM.showAddRecord = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .semibold))
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .toolbarBackground(.visible, for: .bottomBar)
            .toolbarBackground(.ultraThinMaterial, for: .bottomBar)
        }
        .tint(Color.dashAccent)
        .task {
            await avatarVM.refresh()
        }
        .sheet(isPresented: $recordsVM.showAddRecord) {
            AddEditRecordView(mode: .add)
                .environmentObject(recordsVM)
        }
    }
}

#Preview {
    MainTabView(authVM: AuthViewModel())
}
