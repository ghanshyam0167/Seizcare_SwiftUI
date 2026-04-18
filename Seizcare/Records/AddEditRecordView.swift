//
//  AddEditRecordView.swift
//  Seizcare
//
//  Unified Add / Edit screen for manual seizure records.

import SwiftUI

// MARK: - Mode

enum AddEditMode {
    case add
    case edit(SeizureRecord)

    var isEdit: Bool {
        if case .edit = self { return true }
        return false
    }

    var title: String {
        isEdit ? "Edit Record" : "Add Record"
    }
}

// MARK: - View

struct AddEditRecordView: View {
    @EnvironmentObject var vm: RecordsViewModel
    @Environment(\.dismiss) private var dismiss

    let mode: AddEditMode

    // Form state
    @State private var startTime: Date
    @State private var durationMinutes: Int
    @State private var seizureType: SeizureType
    @State private var selectedTriggers: Set<SeizureTrigger>
    @State private var notes: String
    @State private var location: String

    // Validation
    private var isFormValid: Bool {
        !selectedTriggers.isEmpty && !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // Scroll focus
    @FocusState private var notesFieldFocused: Bool
    @FocusState private var locationFieldFocused: Bool

    init(mode: AddEditMode) {
        self.mode = mode
        switch mode {
        case .add:
            _startTime         = State(initialValue: Date())
            _durationMinutes   = State(initialValue: 5)
            _seizureType       = State(initialValue: .mild)
            _selectedTriggers  = State(initialValue: [])
            _notes             = State(initialValue: "")
            _location          = State(initialValue: "")
        case .edit(let record):
            _startTime         = State(initialValue: record.startTime)
            let mins = Int(record.duration / 60)
            _durationMinutes   = State(initialValue: mins == 0 ? 1 : mins)
            _seizureType       = State(initialValue: record.type)
            _selectedTriggers  = State(initialValue: Set(record.triggers))
            _notes             = State(initialValue: record.notes ?? "")
            _location          = State(initialValue: record.location ?? "")
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {


                        // ── Time Pickers ──────────────────────────────────
                        timePickers

                        // ── Type Selector ─────────────────────────────────
                        typeSelector

                        // ── Triggers ──────────────────────────────────────
                        triggersSection

                        // ── Notes ─────────────────────────────────────────
                        notesSection

                        // ── Location ──────────────────────────────────────
                        locationSection

                        // ── Delete (edit mode only) ───────────────────────
                        if mode.isEdit {
                            deleteButton
                        }

                        // Bottom padding
                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.dashSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: saveRecord) {
                        Text("Save")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.dashSeizure)
                            .opacity(isFormValid ? 1.0 : 0.4)
                    }
                    .disabled(!isFormValid)
                }
            }
        }
    }

    // MARK: - Sub-views



    private var timePickers: some View {
        VStack(spacing: 0) {
            FormSectionHeader(title: "Timing")

            VStack(spacing: 1) {
                DatePickerRow(label: "Date & Time", icon: "calendar.badge.clock", color: .dashSleep, date: $startTime)
                Divider().background(Color.dashTertiary.opacity(0.2)).padding(.leading, 50)
                
                HStack(spacing: 14) {
                    Image(systemName: "timer")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.dashGreen)
                        .frame(width: 28)
                    
                    Text("Duration")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.dashLabel)
                    
                    Spacer()
                    
                    Picker("Duration", selection: $durationMinutes) {
                        ForEach(1...120, id: \.self) { min in
                            Text("\(min) min").tag(min)
                        }
                    }
                    .tint(Color.dashGreen)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color.dashCard)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var typeSelector: some View {
        VStack(spacing: 8) {
            FormSectionHeader(title: "Severity")

            Picker("Type", selection: $seizureType) {
                ForEach(SeizureType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(14)
            .background(Color.dashCard)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var triggersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            FormSectionHeader(title: "Triggers")

            VStack(alignment: .leading, spacing: 12) {
                FlowLayout(spacing: 8) {
                    ForEach(SeizureTrigger.allCases) { trigger in
                        TriggerChip(
                            trigger: trigger,
                            isSelected: selectedTriggers.contains(trigger)
                        ) {
                            if selectedTriggers.contains(trigger) {
                                selectedTriggers.remove(trigger)
                            } else {
                                selectedTriggers.insert(trigger)
                            }
                        }
                    }
                }
                if !selectedTriggers.isEmpty {
                    HStack(spacing: 4) {
                        Text("\(selectedTriggers.count) selected")
                            .font(.caption2)
                            .foregroundStyle(Color.dashSecondary)
                        Spacer()
                        Button("Clear") { selectedTriggers.removeAll() }
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.dashSeizure.opacity(0.8))
                    }
                }
            }
            .padding(16)
            .background(Color.dashCard)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            FormSectionHeader(title: "Notes")

            ZStack(alignment: .topLeading) {
                if notes.isEmpty {
                    Text("Add any observations, symptoms, or context…")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.dashTertiary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $notes)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.dashLabel)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 100, maxHeight: 200)
                    .focused($notesFieldFocused)
            }
            .padding(12)
            .background(Color.dashCard)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        notesFieldFocused ? Color.dashSleep.opacity(0.4) : Color.dashTertiary.opacity(0.15),
                        lineWidth: 1
                    )
            )
        }
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            FormSectionHeader(title: "Location (Optional)")

            HStack(spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color(red: 0.4, green: 0.8, blue: 0.6))
                TextField("e.g. Home, Office, Gym…", text: $location)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.dashLabel)
                    .focused($locationFieldFocused)
                    .autocorrectionDisabled()
            }
            .padding(14)
            .background(Color.dashCard)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        locationFieldFocused ? Color.dashSleep.opacity(0.4) : Color.dashTertiary.opacity(0.15),
                        lineWidth: 1
                    )
            )
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            if case .edit(let record) = mode {
                vm.deleteRecord(record)
                dismiss()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                Text("Delete Record")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(Color.dashSeizure)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.dashSeizure.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    // MARK: - Actions

    private func saveRecord() {
        let finalEndTime = startTime.addingTimeInterval(TimeInterval(durationMinutes * 60))

        let record = SeizureRecord(
            id: existingId,
            userId: MockDashboardData.userId,
            entryType: .manual,
            startTime: startTime,
            endTime: finalEndTime,
            type: seizureType,
            triggers: Array(selectedTriggers),
            location: location.isEmpty ? nil : location,
            notes: notes.isEmpty ? nil : notes
        )

        switch mode {
        case .add:
            vm.addRecord(record)
        case .edit:
            vm.updateRecord(record)
        }
        dismiss()
    }

    private var existingId: UUID {
        if case .edit(let record) = mode { return record.id }
        return UUID()
    }


}

// MARK: - Form Helpers

private struct FormSectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.dashTertiary)
            .tracking(1.2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}

private struct DatePickerRow: View {
    let label: String
    let icon: String
    let color: Color
    @Binding var date: Date

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
                .frame(width: 28)

            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.dashLabel)

            Spacer()

            DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Preview

#Preview {
    AddEditRecordView(mode: .add)
        .environmentObject(RecordsViewModel())
}
