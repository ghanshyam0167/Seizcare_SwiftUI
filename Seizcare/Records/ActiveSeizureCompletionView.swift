//
//  ActiveSeizureCompletionView.swift
//  Seizcare
//

import SwiftUI

struct ActiveSeizureCompletionView: View {
    @Environment(\.dismiss) private var dismiss
    
    let record: SeizureRecord
    
    @State private var endTime: Date
    @State private var selectedType: SeizureType?
    @State private var selectedTriggers: Set<SeizureTrigger> = []
    @State private var notes: String = ""
    @State private var isSaving = false
    
    init(record: SeizureRecord) {
        self.record = record
        _endTime = State(initialValue: Date())
        _selectedType = State(initialValue: record.type)
        _selectedTriggers = State(initialValue: Set(record.triggers))
        _notes = State(initialValue: record.notes ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Details")) {
                    DatePicker("Start Time", selection: .constant(record.startTime), displayedComponents: [.date, .hourAndMinute])
                        .disabled(true)
                    
                    DatePicker("End Time", selection: $endTime, in: record.startTime..., displayedComponents: [.date, .hourAndMinute])
                }
                
                Section(header: Text("Severity")) {
                    Picker("Severity Type", selection: $selectedType) {
                        Text("None").tag(SeizureType?.none)
                        ForEach(SeizureType.allCases, id: \.self) { type in
                            Text(type.localizationKey.localized).tag(SeizureType?.some(type))
                        }
                    }
                }
                
                Section(header: Text("Triggers")) {
                    ForEach(SeizureTrigger.allCases) { trigger in
                        Toggle(trigger.localizationKey.localized, isOn: Binding(
                            get: { selectedTriggers.contains(trigger) },
                            set: { isSelected in
                                if isSelected {
                                    selectedTriggers.insert(trigger)
                                } else {
                                    selectedTriggers.remove(trigger)
                                }
                            }
                        ))
                    }
                }
                
                Section(header: Text("Notes")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Complete Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveRecord()
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .overlay {
                if isSaving {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    ProgressView()
                        .padding()
                        .background(Color.white)
                        .cornerRadius(8)
                }
            }
        }
    }
    
    private func saveRecord() async {
        isSaving = true
        
        let updatedRecord = SeizureRecord(
            id: record.id,
            userId: record.userId,
            entryType: record.entryType,
            startTime: record.startTime,
            endTime: endTime,
            type: selectedType,
            triggers: Array(selectedTriggers),
            location: record.location,
            notes: notes.isEmpty ? nil : notes
        )
        
        do {
            try await SupabaseService.shared.updateSeizureRecord(updatedRecord)
            
            // Stop tagging
            SensorLogManager.shared.stopTagging(recordId: record.id)
            
            // Post notification to tell Dashboard to refresh
            NotificationCenter.default.post(name: NSNotification.Name("RefreshRecords"), object: nil)
            
            await MainActor.run {
                isSaving = false
                dismiss()
            }
        } catch {
            print("❌ Failed to update seizure record: \(error)")
            await MainActor.run {
                isSaving = false
            }
        }
    }
}
