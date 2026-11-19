import SwiftUI

struct ScanProgressSheet: View {
    @EnvironmentObject var scanCoordinator: ScanCoordinator

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                if scanCoordinator.isScanning {
                    scanningContent
                } else if !scanCoordinator.results.isEmpty {
                    resultsList
                } else {
                    idleContent
                }
            }
            .navigationTitle("Scan")
        }
    }

    private var scanningContent: some View {
        VStack(spacing: 16) {
            ProgressView(value: scanCoordinator.progress)
                .progressViewStyle(.linear)
                .padding(.horizontal)

            Text("\(scanCoordinator.scannedCount) / \(scanCoordinator.totalCount)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let file = scanCoordinator.currentFile {
                Text(file)
                    .font(.caption2)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }

            Button("Cancel") {
                scanCoordinator.cancelScan()
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .padding(.top, 24)
    }

    private var resultsList: some View {
        List {
            Section("Results — \(scanCoordinator.results.count) issues") {
                ForEach(scanCoordinator.results) { result in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: severityIcon(result.severity))
                                .foregroundColor(severityColor(result.severity))
                            Text(result.issue)
                                .font(.body)
                        }
                        Text(result.path)
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Section {
                Button("Start New Scan") {
                    scanCoordinator.startScan()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var idleContent: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No scan in progress")
                .foregroundStyle(.secondary)

            Button("Start Scan") {
                scanCoordinator.startScan()
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
    }

    private func severityIcon(_ severity: ScanCoordinator.Severity) -> String {
        switch severity {
        case .info:    return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error:   return "xmark.octagon"
        }
    }

    private func severityColor(_ severity: ScanCoordinator.Severity) -> Color {
        switch severity {
        case .info:    return .blue
        case .warning: return .orange
        case .error:   return .red
        }
    }
}
