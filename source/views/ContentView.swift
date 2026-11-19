// ContentView.swift — Main content view with adaptive layout
// Reconstructed from 5013 v3.2.17 binary
//
// Layout structure decoded from mangled SwiftUI generic type signatures:
// - body: _ConditionalContent(regularLayout, compactLayout) based on horizontal size class
// - regularLayout: HStack { NavigationView(sidebarList) | Divider | sectionStack } + scanBannerOverlay
// - compactLayout: TabView with ForEach(AppSection) { sectionView + scanBannerOverlay }
// - sidebarList: VStack { titaniumCard(AppLogo + Text) + ForEach(sections, Button { sectionItem }) }
// - sectionStack: ForEach(AppSection) { sectionView with frame/opacity/zIndex animation }

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var patchDraftCoordinator: PatchDraftCoordinator
    @EnvironmentObject var fileOperationCoordinator: FileOperationCoordinator
    @EnvironmentObject var patchStore: PatchProjectStore
    @EnvironmentObject var repositoryStore: PackageRepositoryStore
    @EnvironmentObject var migrationTaskCenter: MigrationTaskCenter
    @EnvironmentObject var themeManager: AppThemeManager
    @EnvironmentObject var themePalette: AppThemePalette

    @StateObject private var scanCoordinator = ScanCoordinator()

    @State private var selectedSection: AppSection = .files
    @State private var showOnboarding: Bool = false

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                regularLayout
            } else {
                compactLayout
            }
        }
        .environmentObject(scanCoordinator)
    }

    // MARK: - Regular (iPad / wide) layout

    private var regularLayout: some View {
        ZStack {
            HStack(spacing: 0) {
                NavigationView {
                    sidebarList
                        .navigationTitle("5013")
                }
                .navigationViewStyle(.stack)
                .frame(width: 280)

                Divider()

                sectionStack
            }

            scanBannerOverlay
        }
    }

    // MARK: - Compact (iPhone) layout

    private var compactLayout: some View {
        TabView(selection: $selectedSection) {
            ForEach(AppSection.allCases) { section in
                sectionView(section)
                    .tag(section)
                    .tabItem {
                        Label(section.title, systemImage: section.iconName)
                    }
                    .safeAreaInset(edge: .bottom) {
                        Group {
                            sectionView(section)
                            scanBannerOverlay
                        }
                    }
            }
        }
    }

    // MARK: - Sidebar

    private var sidebarList: some View {
        VStack(spacing: 0) {
            // App logo header card
            HStack {
                AppLogo()
                Text("5013")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()

            Divider()

            // Section navigation buttons
            ForEach(Array(AppSection.allCases.enumerated()), id: \.offset) { index, section in
                Button {
                    selectSection(section)
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(selectedSection == section ? Color.accentColor.opacity(0.15) : Color.clear)
                            .frame(maxWidth: .infinity)

                        HStack {
                            Image(systemName: section.iconName)
                                .font(.body)
                            Text(section.title)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .contentShape(Rectangle())
                    .overlay(alignment: .leading) {
                        if selectedSection == section {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 6, height: 6)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)

                if index < AppSection.allCases.count - 1 {
                    Divider()
                        .padding(.horizontal)
                }
            }

            Spacer()
        }
        .padding(8)
    }

    // MARK: - Section stack (regular layout)

    private var sectionStack: some View {
        ZStack {
            ForEach(AppSection.allCases) { section in
                sectionView(section)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(selectedSection == section ? 1 : 0)
                    .allowsHitTesting(selectedSection == section)
                    .zIndex(selectedSection == section ? 1 : 0)
                    .accessibilityHidden(selectedSection != section)
            }
        }
    }

    // MARK: - Section content

    @ViewBuilder
    private func sectionView(_ section: AppSection) -> some View {
        switch section {
        case .files:
            FileBrowserView()
        case .patches:
            PatchEditorView()
        case .repository:
            RepositoryBrowserView()
        case .settings:
            SettingsView()
        case .scan:
            ScanProgressSheet()
        }
    }

    // MARK: - Scan banner overlay

    private var scanBannerOverlay: some View {
        Group {
            if scanCoordinator.isScanning {
                VStack {
                    Spacer()
                    Text("Scanning...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .padding()
                }
            }
        }
    }

    // MARK: - Actions

    private func selectSection(_ section: AppSection) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedSection = section
        }
    }

    private func focusSharedDocument() {
        selectedSection = .files
    }
}
