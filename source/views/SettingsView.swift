import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: AppThemeManager

    @AppStorage("appLanguage") private var appLanguage: String = "en"
    @State private var showRespring = false
    @State private var showDiagnosticExport = false
    @State private var showWallpaperReset = false

    var body: some View {
        NavigationView {
            List {
                statusSection
                appearanceSection
                backupSection
                airliftSection
                advancedSection
                aboutSection
            }
            .navigationTitle("Settings")
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        Section {
            HStack {
                Text("Exploit Status")
                Spacer()
                Text(statusLabel)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Sandbox Backend")
                Spacer()
                Text(appState.activeBackend?.rawValue ?? "none")
                    .foregroundStyle(.secondary)
            }

            if case .ready = appState.exploitStatus {
                HStack {
                    Text("Access")
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
        } header: {
            Text("Status")
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section("Appearance") {
            VStack(alignment: .leading) {
                AppLogo()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }

            TitaniumThemeSwatchStrip(manager: themeManager)

            Picker("Language", selection: $appLanguage) {
                Text("English").tag("en")
                Text("Japanese").tag("ja")
                Text("Korean").tag("ko")
                Text("Chinese (Simplified)").tag("zh-Hans")
                Text("Chinese (Traditional)").tag("zh-Hant")
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Backup

    private var backupSection: some View {
        Section("Backup") {
            NavigationLink("Backup Center") {
                BackupCenterView()
            }
        }
    }

    // MARK: - AirLift

    private var airliftSection: some View {
        Section("AirLift") {
            NavigationLink("AirLift") {
                AirLiftView()
            }
        }
    }

    // MARK: - Advanced

    private var advancedSection: some View {
        Section("Advanced") {
            Button("Respring") {
                showRespring = true
            }
            .alert("Respring", isPresented: $showRespring) {
                Button("Respring", role: .destructive) { performRespring() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will restart SpringBoard.")
            }

            Toggle("Verbose Logging", isOn: .constant(false))

            Button {
                showDiagnosticExport = true
            } label: {
                HStack {
                    Text("Export Diagnostic Log")
                    Spacer()
                    Image(systemName: "square.and.arrow.up")
                }
            }

            NavigationLink("Wallpaper Reset") {
                WallpaperResetSettingsView()
            }

            NavigationLink("Log Viewer") {
                LogView()
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("iOS")
                Spacer()
                Text(AppInfo.osVersion)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Build")
                Spacer()
                Text(AppInfo.osBuild)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Device")
                Spacer()
                Text(AppInfo.machineName)
                    .foregroundStyle(.secondary)
            }

            NavigationLink("Acknowledgements") {
                AcknowledgementsView()
            }

            Link("Source Code", destination: URL(string: "https://github.com/5013app/5013")!)
        }
    }

    // MARK: - Helpers

    private var statusLabel: String {
        switch appState.exploitStatus {
        case .idle: return "Idle"
        case .running: return "Running"
        case .failed(_, let message): return message ?? "Failed"
        case .ready(let backend): return backend.rawValue
        }
    }

    private func performRespring() {
        // kill SpringBoard via posix_spawn or sbreload
    }
}

// MARK: - Sub-views

struct TitaniumThemeSwatchStrip: View {
    @ObservedObject var manager: AppThemeManager

    private let swatches: [(String, Color)] = [
        ("Default", .accentColor),
        ("Red", .red),
        ("Orange", .orange),
        ("Green", .green),
        ("Purple", .purple),
        ("Pink", .pink),
        ("Indigo", .indigo),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(swatches, id: \.0) { name, color in
                    Button {
                        manager.setTheme(name)
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 28, height: 28)
                            .overlay {
                                if manager.currentTheme == name {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                }
                            }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct BackupCenterView: View {
    @State private var records: [BackupRecord] = []

    var body: some View {
        List {
            if records.isEmpty {
                Text("No backups")
                    .foregroundColor(.secondary)
            }
            ForEach(records) { record in
                VStack(alignment: .leading) {
                    Text(record.reason)
                        .font(.body)
                    HStack {
                        Text(record.feature.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(record.createdAt, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Backup Center")
        .onAppear {
            records = BackupCenter.shared.records()
        }
    }
}

struct AcknowledgementsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    acknowledgement("opa334", "Kernel exploit (socket PCB corruption)")
                    acknowledgement("Ian Beer / Google Project Zero", "IOSurface techniques")
                    acknowledgement("Linus Henze", "Fugu jailbreak inspiration")
                    acknowledgement("Sam Bingner", "Sandbox escape research")
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 16)
        }
        .navigationTitle("Acknowledgements")
    }

    private func acknowledgement(_ name: String, _ contribution: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.headline)
            Text(contribution)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

struct WallpaperResetSettingsView: View {
    @State private var showConfirm = false

    var body: some View {
        List {
            Section {
                Text("Reset wallpapers to iOS defaults. A backup will be created automatically.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            Section {
                Button("Reset Wallpapers", role: .destructive) {
                    showConfirm = true
                }
                .alert("Reset Wallpapers?", isPresented: $showConfirm) {
                    Button("Reset", role: .destructive) { resetWallpapers() }
                    Button("Cancel", role: .cancel) {}
                }
            }
        }
        .navigationTitle("Wallpaper Reset")
    }

    private func resetWallpapers() {
        // Backup then remove custom wallpaper files
    }
}

struct AirLiftView: View {
    @ObservedObject var service = AirLiftService.shared

    var body: some View {
        List {
            Section {
                LabeledContent("Pairing") {
                    Text(service.hasPairing ? "Present" : "None")
                        .foregroundColor(service.hasPairing ? .green : .secondary)
                }
                LabeledContent("Status") {
                    Text(service.statusKey)
                        .foregroundColor(.secondary)
                }
                if let error = service.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            } header: {
                Text("Status")
            }

            Section {
                Button("Import Pairing File") {
                    // Present document picker for pairing import
                }
                .disabled(service.isBusy)

                Button("Probe Connection") {
                    service.probe()
                }
                .disabled(service.isBusy || !service.hasPairing)

                if service.hasPairing {
                    Button("Remove Pairing", role: .destructive) {
                        service.removePairing()
                    }
                    .disabled(service.isBusy)
                }
            } header: {
                Text("Actions")
            }

            if service.isBusy {
                Section {
                    HStack {
                        ProgressView()
                        Text("Working...")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("AirLift")
    }
}

struct LogView: View {
    @State private var entries: [AppLog.Entry] = []
    @State private var levelFilter: AppLog.Level?

    var body: some View {
        List(filteredEntries) { entry in
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(entry.level.rawValue.uppercased())
                        .font(.caption2.bold())
                        .foregroundColor(levelColor(entry.level))
                    Text(entry.category)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(entry.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Text(entry.message)
                    .font(.caption)
                    .lineLimit(3)
            }
        }
        .navigationTitle("Log")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("All") { levelFilter = nil }
                    Button("Errors") { levelFilter = .error }
                    Button("Warnings") { levelFilter = .warning }
                    Button("Info") { levelFilter = .info }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .onAppear { entries = AppLog.shared.allEntries() }
    }

    private var filteredEntries: [AppLog.Entry] {
        guard let filter = levelFilter else { return entries }
        return entries.filter { $0.level == filter }
    }

    private func levelColor(_ level: AppLog.Level) -> Color {
        switch level {
        case .debug:   return .secondary
        case .info:    return .blue
        case .warning: return .orange
        case .error:   return .red
        case .fault:   return .red
        }
    }
}

struct DiagnosticLogExportButton: View {
    @State private var showShare = false

    var body: some View {
        Button {
            showShare = true
        } label: {
            Label("Export Logs", systemImage: "square.and.arrow.up")
        }
        .sheet(isPresented: $showShare) {
            let data = AppLog.shared.export()
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("5013_diagnostic.log")
            let _ = try? data.write(to: tempURL)
            ShareSheet(items: [tempURL])
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct RespringButton: View {
    @State private var showConfirm = false

    var body: some View {
        Button("Respring") { showConfirm = true }
            .alert("Respring?", isPresented: $showConfirm) {
                Button("Respring", role: .destructive) {
                    // posix_spawn sbreload
                }
                Button("Cancel", role: .cancel) {}
            }
    }
}
