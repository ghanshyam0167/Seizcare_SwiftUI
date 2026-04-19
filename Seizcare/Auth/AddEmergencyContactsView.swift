//
//  AddEmergencyContactsView.swift
//  Seizcare
//

import SwiftUI
import Contacts

struct AddEmergencyContactsView: View {
    @ObservedObject var vm: AuthViewModel
    @ObservedObject private var contactModel = EmergencyContactDataModel.shared
    @State private var showingContactPicker = false
    @Environment(\.dismiss) private var dismiss
    
    // We observe the shared data model to get the live list of contacts
    private var contacts: [EmergencyContact] {
        contactModel.getContactsForCurrentUser()
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Navigation Bar
                HStack {
                    CustomBackButton {
                        if vm.isAuthenticated {
                            dismiss()
                        } else {
                            vm.goBack()
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            
            Spacer().frame(height: 10)
            
            // Header
            VStack(spacing: 8) {
                Image(systemName: "person.badge.plus.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.authPrimaryButton)
                    .padding(.bottom, 8)
                
                Text("Emergency Contacts")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.authPrimaryText)
                
                Text("Add at least 1 contact who will be notified in case of a seizure detection.")
                    .font(.system(size: 15))
                    .foregroundColor(.authSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 4)
            }
            
            Spacer().frame(height: 32)
            
            // Contacts List / Empty State
            VStack(spacing: 16) {
                if contacts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.authSecondaryText.opacity(0.3))
                        Text("No contacts added yet")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.authSecondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .background(Color.authFieldBackground.opacity(0.5))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                            .foregroundColor(.authInputBorder)
                    )
                } else {
                    ForEach(contacts, id: \.id) { contact in
                        HStack(spacing: 16) {
                            Circle()
                                .fill(Color.authPrimaryButton.opacity(0.1))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Text(String(contact.name.prefix(1)).uppercased())
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.authPrimaryButton)
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(contact.name)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.authPrimaryText)
                                Text(contact.contactNumber)
                                    .font(.system(size: 14))
                                    .foregroundColor(.authSecondaryText)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                withAnimation {
                                    EmergencyContactDataModel.shared.deleteContact(id: contact.id)
                                }
                            }) {
                                Image(systemName: "trash.fill")
                                    .foregroundColor(.errorRed.opacity(0.8))
                                    .padding(8)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.authCardBackground)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)
                    }
                }
                
                if contacts.count < 3 {
                    Button(action: { showingContactPicker = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add from Contacts")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.authPrimaryButton)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.authPrimaryButton.opacity(0.1))
                        .cornerRadius(14)
                    }
                    .padding(.top, 8)
                } else {
                    Text("Maximum 3 contacts reached")
                        .font(.system(size: 13))
                        .foregroundColor(.authSecondaryText)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Footer Action
            VStack(spacing: 16) {
                Button(action: {
                    if vm.isAuthenticated {
                        dismiss()
                    } else {
                        vm.finishOnboarding()
                    }
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(contacts.count >= 1 ? Color.authPrimaryButton : Color.authButtonDisabled)
                            .frame(height: 56)
                        
                        Text(vm.isAuthenticated ? "Done" : "Next")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .disabled(contacts.count < 1)
                
                Text("\(contacts.count)/3 Contacts Added")
                    .font(.system(size: 13))
                    .foregroundColor(contacts.count >= 1 ? .successGreen : .authSecondaryText)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            }
            
            if contactModel.isRefreshing {
                Color.black.opacity(0.1).ignoresSafeArea()
                LoadingView()
            }
        }
        .sheet(isPresented: $showingContactPicker) {
            ContactPicker(isPresented: $showingContactPicker) { cnContact in
                let fullName = [cnContact.givenName, cnContact.familyName]
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespaces)
                
                let displayName = fullName.isEmpty ? "Unknown" : fullName
                
                if let phone = cnContact.phoneNumbers.first?.value.stringValue {
                    let digitsOnly = phone.filter { $0.isNumber }
                    if digitsOnly.count >= 10 {
                        let validNumber = String(digitsOnly.suffix(10))
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                            withAnimation {
                                contactModel.addContact(name: displayName, contactNumber: validNumber)
                            }
                        }
                    }
                }
            }
        }
        .task {
            // Load existing contacts from Supabase
            await contactModel.refreshContacts()
        }
    }
}

#Preview {
    ZStack {
        Color.authBackground.ignoresSafeArea()
        AddEmergencyContactsView(vm: AuthViewModel())
    }
}
