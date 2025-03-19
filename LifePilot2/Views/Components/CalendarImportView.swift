import SwiftUI
import EventKit

struct CalendarImportView: View {
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject var viewModel: WeeklyScheduleViewModel
    
    @State private var selectedCalendars: [String: Bool] = [:]
    @State private var availableCalendars: [EKCalendar] = []
    @State private var isImporting = false
    @State private var importResult: ImportResult?
    @State private var error: String?
    
    private let eventStore = EKEventStore()
    
    var body: some View {
        NavigationView {
            VStack {
                if isImporting {
                    importingView
                } else if let result = importResult {
                    resultView(result)
                } else {
                    calendarSelectionView
                }
            }
            .navigationTitle("Import Calendar Events")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                if !isImporting && importResult == nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Import") {
                            importEvents()
                        }
                        .disabled(selectedCalendars.values.filter { $0 }.isEmpty)
                    }
                }
            }
            .onAppear {
                requestCalendarAccess()
            }
            .alert(item: Binding<ImportResult?>(
                get: { error != nil ? ImportResult(imported: 0, errors: 1) : nil },
                set: { _ in error = nil }
            )) { _ in
                Alert(
                    title: Text("Error"),
                    message: Text(error ?? "Unknown error"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private var importingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Importing events...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("This may take a moment")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func resultView(_ result: ImportResult) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Import Complete")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Successfully imported \(result.imported) events.")
                .font(.headline)
            
            if result.errors > 0 {
                Text("Failed to import \(result.errors) events.")
                    .font(.subheadline)
                    .foregroundColor(.orange)
            }
            
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Done")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var calendarSelectionView: some View {
        List {
            Section(header: Text("Select Calendars")) {
                if availableCalendars.isEmpty {
                    Text("No calendars found")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(availableCalendars, id: \.calendarIdentifier) { calendar in
                        HStack {
                            Circle()
                                .fill(Color(calendar.cgColor))
                                .frame(width: 16, height: 16)
                            
                            Text(calendar.title)
                            
                            Spacer()
                            
                            if selectedCalendars[calendar.calendarIdentifier] ?? false {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleCalendarSelection(calendar.calendarIdentifier)
                        }
                    }
                }
            }
            
            Section(header: Text("Import Options")) {
                Picker("Time Range", selection: $viewModel.importRange) {
                    Text("1 Week").tag(ImportRange.oneWeek)
                    Text("2 Weeks").tag(ImportRange.twoWeeks)
                    Text("1 Month").tag(ImportRange.oneMonth)
                }
                
                Toggle("Skip all-day events", isOn: $viewModel.skipAllDayEvents)
                Toggle("Import as read-only", isOn: $viewModel.importAsReadOnly)
            }
            
            Section(header: Text("Information")) {
                Text("Events will be imported into your LifePilot schedule. You can edit or delete them after import unless imported as read-only.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func requestCalendarAccess() {
        eventStore.requestAccess(to: .event) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    loadCalendars()
                } else {
                    self.error = "Calendar access denied. Please enable access in Settings."
                }
            }
        }
    }
    
    private func loadCalendars() {
        let calendars = eventStore.calendars(for: .event)
        availableCalendars = calendars.sorted { $0.title < $1.title }
        
        // Initialize selected calendars dictionary
        for calendar in availableCalendars {
            selectedCalendars[calendar.calendarIdentifier] = false
        }
    }
    
    private func toggleCalendarSelection(_ identifier: String) {
        if let isSelected = selectedCalendars[identifier] {
            selectedCalendars[identifier] = !isSelected
        }
    }
    
    private func importEvents() {
        isImporting = true
        
        // Get selected calendar identifiers
        let selectedIdentifiers = selectedCalendars.filter { $0.value }.map { $0.key }
        
        // Perform the import
        viewModel.importFromCalendars(
            identifiers: selectedIdentifiers,
            eventStore: eventStore
        ) { result in
            DispatchQueue.main.async {
                self.isImporting = false
                self.importResult = result
            }
        }
    }
}

struct ImportResult: Identifiable {
    let id = UUID()
    let imported: Int
    let errors: Int
}

enum ImportRange: Int, CaseIterable {
    case oneWeek = 7
    case twoWeeks = 14
    case oneMonth = 30
}
