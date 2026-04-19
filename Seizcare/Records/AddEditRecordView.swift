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
        isEdit ? "edit_record".localized : "add_record".localized
    }
}

// MARK: - View

struct AddEditRecordView: View {
    @EnvironmentObject var vm: RecordsViewModel
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.dismiss) private var dismiss

    let mode: AddEditMode

    // Form state
    @State private var startTime: Date
    @State private var durationMinutes: Int
    @State private var seizureType: SeizureType
    @State private var selectedTriggers: Set<SeizureTrigger>
    @State private var notes: String
    @State private var location: String
    @State private var showingDeleteConfirmation = false

    // Validation
    private var isFormValid: Bool {
        hasRequiredFields
        && !isStartTimeInFuture
        && (!mode.isEdit || hasChanges)
    }

    private var hasRequiredFields: Bool {
        !selectedTriggers.isEmpty
    }

    private var isStartTimeInFuture: Bool {
        startTime > Date()
    }

    private var hasChanges: Bool {
        guard case .edit(let record) = mode else { return true }
        return startTime != record.startTime ||
            durationMinutes != normalizedDurationMinutes(for: record) ||
            seizureType != record.type ||
            selectedTriggers != Set(record.triggers) ||
            normalizedOptionalText(notes) != normalizedOptionalText(record.notes ?? "") ||
            normalizedOptionalText(location) != normalizedOptionalText(record.location ?? "")
    }

    private var isAutomatic: Bool {
        if case .edit(let record) = mode {
            return record.entryType == .automatic
        }
        return false
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

                        // ── Auto-detected banner ───────────────────────────
                        if isAutomatic {
                            HStack(spacing: 10) {
                                Image(systemName: "waveform.path.ecg")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.dashSleep)
                                Text("auto_detected_banner".localized)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.dashSecondary)
                                    .lineSpacing(3)
                            }
                            .padding(12)
                            .background(Color.dashSleep.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.dashSleep.opacity(0.25), lineWidth: 1))
                        }

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
                    Button("cancel".localized) { dismiss() }
                        .foregroundStyle(Color.dashSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { Task { await saveRecord() } }) {
                        Text("save".localized)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.dashSeizure)
                            .opacity(isFormValid ? 1.0 : 0.4)
                    }
                    .disabled(!isFormValid)
                }
            }
        }
        .alert("delete_record".localized, isPresented: $showingDeleteConfirmation) {
            Button("cancel".localized, role: .cancel) {}
            Button("delete_record".localized, role: .destructive) {
                deleteRecord()
            }
        } message: {
            Text("delete_record_confirmation".localized)
        }
    }

    // MARK: - Sub-views



    private var timePickers: some View {
        VStack(spacing: 0) {
            FormSectionHeader(title: "timing".localized)

            VStack(spacing: 1) {
                DatePickerRow(label: "date_time".localized, icon: "calendar.badge.clock", color: .dashSleep, maximumDate: Date(), date: $startTime)
                    .disabled(isAutomatic)
                    .opacity(isAutomatic ? 0.6 : 1.0)
                Divider().background(Color.dashTertiary.opacity(0.2)).padding(.leading, 50)
                
                HStack(spacing: 14) {
                    Image(systemName: "timer")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.dashGreen)
                        .frame(width: 28)
                    
                    Text("duration".localized)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.dashLabel)
                    
                    Spacer()
                    
                    Picker("duration".localized, selection: $durationMinutes) {
                        ForEach(1...120, id: \.self) { min in
                            Text("\(min) \("min_unit".localized)").tag(min)
                        }
                    }
                    .tint(Color.dashGreen)
                    .disabled(isAutomatic)
                }
                .opacity(isAutomatic ? 0.6 : 1.0)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color.dashCard)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            if isStartTimeInFuture {
                Text("future_date_time_not_allowed".localized)
                    .font(.caption)
                    .foregroundStyle(Color.dashSeizure)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.top, 6)
            }
        }
    }

    private var typeSelector: some View {
        VStack(spacing: 8) {
            FormSectionHeader(title: "severity".localized)

            Picker("severity".localized, selection: $seizureType) {
                ForEach(SeizureType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .disabled(isAutomatic)
            .opacity(isAutomatic ? 0.6 : 1.0)
            .padding(14)
            .background(Color.dashCard)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var triggersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            FormSectionHeader(title: "triggers".localized)

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
                        Text(String(format: "selected_count".localized, selectedTriggers.count))
                            .font(.caption2)
                            .foregroundStyle(Color.dashSecondary)
                        Spacer()
                        Button("clear".localized) { selectedTriggers.removeAll() }
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
            FormSectionHeader(title: "notes".localized)

            ZStack(alignment: .topLeading) {
                if notes.isEmpty {
                    Text("add_observations".localized)
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
            FormSectionHeader(title: "location_optional".localized)

            HStack(spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color(red: 0.4, green: 0.8, blue: 0.6))
                TextField("location_placeholder".localized, text: $location)
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
            showingDeleteConfirmation = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                Text("delete_record".localized)
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

    private func deleteRecord() {
        if case .edit(let record) = mode {
            vm.deleteRecord(record)
            dismiss()
        }
    }

    private func saveRecord() async {
        guard isFormValid else { return }

        // Get the real authenticated user ID; fall back to mock only in previews
        let userId = await SupabaseService.shared.currentUserId() ?? MockDashboardData.userId
        
        let finalEndTime = startTime.addingTimeInterval(TimeInterval(durationMinutes * 60))
        let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        let record = SeizureRecord(
            id: existingId,
            userId: userId,
            entryType: isAutomatic ? .automatic : .manual,
            startTime: startTime,
            endTime: finalEndTime,
            type: seizureType,
            triggers: Array(selectedTriggers),
            location: trimmedLocation.isEmpty ? nil : trimmedLocation,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes
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

    private func normalizedDurationMinutes(for record: SeizureRecord) -> Int {
        let mins = Int(record.duration / 60)
        return mins == 0 ? 1 : mins
    }

    private func normalizedOptionalText(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }


}

// MARK: - Form Helpers

private struct FormSectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased(with: Locale.current))
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
    let maximumDate: Date
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

            DatePicker("", selection: $date, in: ...maximumDate, displayedComponents: [.date, .hourAndMinute])
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
