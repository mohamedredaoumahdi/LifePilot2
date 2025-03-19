import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject var viewModel: WeeklyScheduleViewModel
    
    @State private var globalNotificationsEnabled = true
    @State private var defaultReminderTime = 15
    @State private var weeklyDigestEnabled = false
    @State private var weeklyDigestDay: DayOfWeek = .sunday
    @State private var weeklyDigestTime = Date()
    @State private var notificationSound = "default"
    
    @State private var notificationStatus: UNAuthorizationStatus?
    @State private var showingPermissionAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Global Settings")) {
                    notificationPermissionRow
                    
                    Toggle("Enable All Notifications", isOn: $globalNotificationsEnabled)
                        .onChange(of: globalNotificationsEnabled) { newValue in
                            viewModel.globalNotificationsEnabled = newValue
                            viewModel.saveNotificationSettings()
                        }
                        .disabled(notificationStatus != .authorized)
                }
                
                if globalNotificationsEnabled {
                    Section(header: Text("Activity Reminders")) {
                        Picker("Default Reminder Time", selection: $defaultReminderTime) {
                            Text("At time of event").tag(0)
                            Text("5 minutes before").tag(5)
                            Text("15 minutes before").tag(15)
                            Text("30 minutes before").tag(30)
                            Text("1 hour before").tag(60)
                        }
                        .onChange(of: defaultReminderTime) { newValue in
                            viewModel.defaultReminderTime = newValue
                            viewModel.saveNotificationSettings()
                        }
                        
                        Picker("Notification Sound", selection: $notificationSound) {
                            Text("Default").tag("default")
                            Text("None").tag("none")
                            Text("Alert").tag("alert")
                            Text("Bell").tag("bell")
                        }
                        .onChange(of: notificationSound) { newValue in
                            viewModel.notificationSound = newValue
                            viewModel.saveNotificationSettings()
                        }
                    }
                    
                    Section(header: Text("Weekly Digest")) {
                        Toggle("Send Weekly Schedule Summary", isOn: $weeklyDigestEnabled)
                            .onChange(of: weeklyDigestEnabled) { newValue in
                                viewModel.weeklyDigestEnabled = newValue
                                viewModel.saveNotificationSettings()
                                
                                if newValue {
                                    viewModel.scheduleWeeklyDigest(day: weeklyDigestDay, time: weeklyDigestTime)
                                } else {
                                    viewModel.cancelWeeklyDigest()
                                }
                            }
                        
                        if weeklyDigestEnabled {
                            Picker("Day of Week", selection: $weeklyDigestDay) {
                                ForEach(DayOfWeek.allCases, id: \.self) { day in
                                    Text(day.rawValue).tag(day)
                                }
                            }
                            .onChange(of: weeklyDigestDay) { newValue in
                                viewModel.weeklyDigestDay = newValue
                                viewModel.saveNotificationSettings()
                                viewModel.scheduleWeeklyDigest(day: newValue, time: weeklyDigestTime)
                            }
                            
                            DatePicker("Time", selection: $weeklyDigestTime, displayedComponents: .hourAndMinute)
                                .onChange(of: weeklyDigestTime) { newValue in
                                    viewModel.weeklyDigestTime = newValue
                                    viewModel.saveNotificationSettings()
                                    viewModel.scheduleWeeklyDigest(day: weeklyDigestDay, time: newValue)
                                }
                        }
                    }
                    
                    Section(header: Text("Manage Notifications")) {
                        Button(action: {
                            viewModel.rebuildAllNotifications()
                        }) {
                            Text("Rebuild All Notifications")
                                .foregroundColor(.blue)
                        }
                        
                        Button(action: {
                            viewModel.cancelAllNotifications()
                        }) {
                            Text("Cancel All Notifications")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Section(header: Text("Information")) {
                    Text("Activity reminders will be sent based on your settings. You can override the default reminder time for individual activities.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Notification Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                // Load current settings
                globalNotificationsEnabled = viewModel.globalNotificationsEnabled
                defaultReminderTime = viewModel.defaultReminderTime
                weeklyDigestEnabled = viewModel.weeklyDigestEnabled
                weeklyDigestDay = viewModel.weeklyDigestDay
                weeklyDigestTime = viewModel.weeklyDigestTime
                notificationSound = viewModel.notificationSound
                
                // Check notification permission status
                checkNotificationStatus()
            }
            .alert(isPresented: $showingPermissionAlert) {
                Alert(
                    title: Text("Notification Access Required"),
                    message: Text("Please enable notifications in your device settings to receive activity reminders."),
                    primaryButton: .default(Text("Open Settings")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
    
    private var notificationPermissionRow: some View {
        HStack {
            Text("Notification Access")
            Spacer()
            if let status = notificationStatus {
                switch status {
                case .authorized:
                    Label("Allowed", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                case .denied:
                    Button(action: {
                        showingPermissionAlert = true
                    }) {
                        Label("Denied", systemImage: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                    }
                case .notDetermined:
                    Label("Not Set", systemImage: "questionmark.circle.fill")
                        .foregroundColor(.orange)
                case .provisional, .ephemeral:
                    Label("Limited", systemImage: "checkmark.circle")
                        .foregroundColor(.yellow)
                @unknown default:
                    Label("Unknown", systemImage: "questionmark.circle")
                        .foregroundColor(.gray)
                }
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(0.8)
            }
        }
    }
    
    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationStatus = settings.authorizationStatus
            }
        }
    }
}
