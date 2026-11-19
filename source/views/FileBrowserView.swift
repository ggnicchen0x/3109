import SwiftUI
import QuickLook
import UniformTypeIdentifiers

struct FileBrowserView: View {
    @EnvironmentObject var fileOperationCoordinator: FileOperationCoordinator
    @StateObject private var favoritesStore = FileFavoritesStore()

    @State private var currentPath: String = "/"
    @State private var entries: [FileEntry] = []
    @State private var sortOrder: SortOrder = .name
    @State private var filterText: String = ""
    @State private var selectedEntries: Set<String> = []
    @State private var isEditing: Bool = false

    // Sheets and alerts
    @State private var showImportPicker = false
    @State private var showExportPicker = false
    @State private var showRenameAlert = false
    @State private var showDeleteConfirm = false
    @State private var showNewFolderAlert = false
    @State private var showConflictSheet = false

    // Quick Look
    @State private var quickLookURL: URL?

    // Rename state
    @State private var renameTarget: FileEntry?
    @State private var renameText: String = ""

    // New folder
    @State private var newFolderName: String = ""

    // Conflict resolution
    @State private var conflictItems: [ConflictItem] = []

    // Export
    @State private var exportURLs: [URL] = []

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                pathBar
                searchBar
                fileList
            }
            .navigationTitle(currentPathName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showImportPicker) { documentImportPicker }
            .sheet(isPresented: $showExportPicker) { documentExportPicker }
            .alert("Rename", isPresented: $showRenameAlert) { renameAlertContent }
            .alert("New Folder", isPresented: $showNewFolderAlert) { newFolderAlertContent }
            .confirmationDialog("Delete \(selectedEntries.count) items?",
                                isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                deleteConfirmContent
            }
            .sheet(isPresented: $showConflictSheet) { conflictSheet }
            .quickLookPreview($quickLookURL)
        }
        .onAppear { refresh() }
    }

    // MARK: - Path bar

    private var pathBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                Button("/") { navigateTo("/") }
                    .font(.caption.monospaced())

                ForEach(pathComponents, id: \.self) { component in
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Button(component) {
                        navigateToComponent(component)
                    }
                    .font(.caption.monospaced())
                    .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Filter", text: $filterText)
                .textFieldStyle(.plain)
            if !filterText.isEmpty {
                Button { filterText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - File list

    private var fileList: some View {
        List(selection: isEditing ? $selectedEntries : nil) {
            if currentPath != "/" {
                Button {
                    navigateUp()
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.doc")
                        Text("..")
                            .foregroundColor(.primary)
                    }
                }
            }

            ForEach(filteredEntries) { entry in
                fileRow(entry)
                    .contextMenu { contextMenu(for: entry) }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { deleteSingle(entry) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button { beginRename(entry) } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.orange)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            favoritesStore.toggle(path: entry.path)
                        } label: {
                            Label(favoritesStore.isFavorite(entry.path) ? "Unfavorite" : "Favorite",
                                  systemImage: favoritesStore.isFavorite(entry.path) ? "star.slash" : "star")
                        }
                        .tint(.yellow)
                    }
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(isEditing ? .active : .inactive))
        .refreshable { refresh() }
    }

    // MARK: - File row

    private func fileRow(_ entry: FileEntry) -> some View {
        Button {
            if entry.isDirectory {
                navigateTo(entry.path)
            } else {
                quickLookURL = URL(fileURLWithPath: entry.path)
            }
        } label: {
            HStack {
                Image(systemName: entry.iconName)
                    .foregroundColor(entry.isDirectory ? .accentColor : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(.body)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Text(entry.formattedSize)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(entry.formattedDate)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if favoritesStore.isFavorite(entry.path) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }

                if entry.isDirectory {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Context menu

    @ViewBuilder
    private func contextMenu(for entry: FileEntry) -> some View {
        Button { copyPath(entry) } label: {
            Label("Copy Path", systemImage: "doc.on.clipboard")
        }
        Button { beginRename(entry) } label: {
            Label("Rename", systemImage: "pencil")
        }
        Button {
            favoritesStore.toggle(path: entry.path)
        } label: {
            Label(favoritesStore.isFavorite(entry.path) ? "Remove Favorite" : "Add Favorite",
                  systemImage: favoritesStore.isFavorite(entry.path) ? "star.slash" : "star")
        }
        if !entry.isDirectory {
            Button {
                exportURLs = [URL(fileURLWithPath: entry.path)]
                showExportPicker = true
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            Button {
                quickLookURL = URL(fileURLWithPath: entry.path)
            } label: {
                Label("Quick Look", systemImage: "eye")
            }
        }
        Divider()
        Button(role: .destructive) { deleteSingle(entry) } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Menu {
                Button { sortOrder = .name } label: { Label("Name", systemImage: "textformat") }
                Button { sortOrder = .date } label: { Label("Date", systemImage: "calendar") }
                Button { sortOrder = .size } label: { Label("Size", systemImage: "arrow.up.arrow.down") }
                Button { sortOrder = .type } label: { Label("Type", systemImage: "doc") }
            } label: {
                Image(systemName: "arrow.up.arrow.down.circle")
            }
        }

        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button { showImportPicker = true } label: {
                Image(systemName: "square.and.arrow.down")
            }
            Button { showNewFolderAlert = true } label: {
                Image(systemName: "folder.badge.plus")
            }
            Button {
                withAnimation { isEditing.toggle() }
                if !isEditing { selectedEntries.removeAll() }
            } label: {
                Text(isEditing ? "Done" : "Select")
            }
        }

        if isEditing && !selectedEntries.isEmpty {
            ToolbarItem(placement: .bottomBar) {
                HStack {
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Spacer()
                    Text("\(selectedEntries.count) selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button {
                        exportURLs = selectedEntries.map { URL(fileURLWithPath: $0) }
                        showExportPicker = true
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    // MARK: - Sheets

    private var documentImportPicker: some View {
        DocumentPickerView(contentTypes: [.item]) { urls in
            importFiles(urls)
        }
    }

    private var documentExportPicker: some View {
        DocumentPickerView(mode: .export, urls: exportURLs) { _ in }
    }

    private var conflictSheet: some View {
        NavigationView {
            List(conflictItems) { item in
                VStack(alignment: .leading) {
                    Text(item.name)
                        .font(.body)
                    Text("Already exists at destination")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        Button("Replace") { resolveConflict(item, action: .replace) }
                        Button("Keep Both") { resolveConflict(item, action: .keepBoth) }
                        Button("Skip") { resolveConflict(item, action: .skip) }
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
            }
            .navigationTitle("File Conflicts")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showConflictSheet = false }
                }
            }
        }
    }

    // MARK: - Alerts

    @ViewBuilder
    private var renameAlertContent: some View {
        TextField("New name", text: $renameText)
        Button("Rename") { performRename() }
        Button("Cancel", role: .cancel) {}
    }

    @ViewBuilder
    private var newFolderAlertContent: some View {
        TextField("Folder name", text: $newFolderName)
        Button("Create") { createFolder() }
        Button("Cancel", role: .cancel) {}
    }

    @ViewBuilder
    private var deleteConfirmContent: some View {
        Button("Delete", role: .destructive) { performDelete() }
        Button("Cancel", role: .cancel) {}
    }

    // MARK: - Navigation

    private var currentPathName: String {
        currentPath == "/" ? "/" : (currentPath as NSString).lastPathComponent
    }

    private var pathComponents: [String] {
        currentPath.split(separator: "/").map(String.init)
    }

    private func navigateTo(_ path: String) {
        currentPath = path
        refresh()
    }

    private func navigateUp() {
        let parent = (currentPath as NSString).deletingLastPathComponent
        navigateTo(parent.isEmpty ? "/" : parent)
    }

    private func navigateToComponent(_ component: String) {
        guard let idx = pathComponents.firstIndex(of: component) else { return }
        let path = "/" + pathComponents[...idx].joined(separator: "/")
        navigateTo(path)
    }

    // MARK: - Data

    private var filteredEntries: [FileEntry] {
        let sorted = entries.sorted(by: sortOrder)
        if filterText.isEmpty { return sorted }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(filterText) }
    }

    private func refresh() {
        let fm = FileManager.default
        let url = URL(fileURLWithPath: currentPath)

        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            entries = []
            return
        }

        entries = contents.compactMap { itemURL in
            guard let rv = try? itemURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]) else {
                return nil
            }
            return FileEntry(
                name: itemURL.lastPathComponent,
                path: itemURL.path,
                isDirectory: rv.isDirectory ?? false,
                size: Int64(rv.fileSize ?? 0),
                modificationDate: rv.contentModificationDate ?? Date.distantPast
            )
        }
    }

    // MARK: - Actions

    private func copyPath(_ entry: FileEntry) {
        UIPasteboard.general.string = entry.path
        AppNoticeCenter.shared.post("Path copied", level: .info)
    }

    private func beginRename(_ entry: FileEntry) {
        renameTarget = entry
        renameText = entry.name
        showRenameAlert = true
    }

    private func performRename() {
        guard let target = renameTarget, !renameText.isEmpty else { return }
        let fm = FileManager.default
        let parent = (target.path as NSString).deletingLastPathComponent
        let newPath = (parent as NSString).appendingPathComponent(renameText)
        do {
            try fm.moveItem(atPath: target.path, toPath: newPath)
            refresh()
            AppNoticeCenter.shared.post("Renamed", level: .success)
        } catch {
            AppNoticeCenter.shared.postError(error)
        }
    }

    private func deleteSingle(_ entry: FileEntry) {
        do {
            try FileManager.default.removeItem(atPath: entry.path)
            refresh()
            AppNoticeCenter.shared.post("Deleted", level: .success)
        } catch {
            AppNoticeCenter.shared.postError(error)
        }
    }

    private func performDelete() {
        let fm = FileManager.default
        var failed = 0
        for path in selectedEntries {
            do { try fm.removeItem(atPath: path) }
            catch { failed += 1 }
        }
        selectedEntries.removeAll()
        isEditing = false
        refresh()
        if failed > 0 {
            AppNoticeCenter.shared.post("Failed to delete \(failed) items", level: .error)
        } else {
            AppNoticeCenter.shared.post("Deleted", level: .success)
        }
    }

    private func createFolder() {
        guard !newFolderName.isEmpty else { return }
        let path = (currentPath as NSString).appendingPathComponent(newFolderName)
        do {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
            newFolderName = ""
            refresh()
        } catch {
            AppNoticeCenter.shared.postError(error)
        }
    }

    private func importFiles(_ urls: [URL]) {
        let fm = FileManager.default
        var conflicts: [ConflictItem] = []

        for url in urls {
            let dest = (currentPath as NSString).appendingPathComponent(url.lastPathComponent)
            if fm.fileExists(atPath: dest) {
                conflicts.append(ConflictItem(name: url.lastPathComponent, sourceURL: url, destinationPath: dest))
            } else {
                do {
                    _ = url.startAccessingSecurityScopedResource()
                    defer { url.stopAccessingSecurityScopedResource() }
                    try fm.copyItem(at: url, to: URL(fileURLWithPath: dest))
                } catch {
                    AppNoticeCenter.shared.postError(error)
                }
            }
        }

        if !conflicts.isEmpty {
            conflictItems = conflicts
            showConflictSheet = true
        }

        refresh()
    }

    private func resolveConflict(_ item: ConflictItem, action: ConflictAction) {
        let fm = FileManager.default
        let destURL = URL(fileURLWithPath: item.destinationPath)

        _ = item.sourceURL.startAccessingSecurityScopedResource()
        defer { item.sourceURL.stopAccessingSecurityScopedResource() }

        do {
            switch action {
            case .replace:
                try fm.removeItem(at: destURL)
                try fm.copyItem(at: item.sourceURL, to: destURL)
            case .keepBoth:
                let ext = destURL.pathExtension
                let name = destURL.deletingPathExtension().lastPathComponent
                let parent = destURL.deletingLastPathComponent()
                var counter = 1
                var newURL: URL
                repeat {
                    let newName = ext.isEmpty ? "\(name) (\(counter))" : "\(name) (\(counter)).\(ext)"
                    newURL = parent.appendingPathComponent(newName)
                    counter += 1
                } while fm.fileExists(atPath: newURL.path)
                try fm.copyItem(at: item.sourceURL, to: newURL)
            case .skip:
                break
            }
        } catch {
            AppNoticeCenter.shared.postError(error)
        }

        conflictItems.removeAll { $0.id == item.id }
        if conflictItems.isEmpty {
            showConflictSheet = false
        }
        refresh()
    }
}

// MARK: - Supporting types

struct FileEntry: Identifiable {
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64
    let modificationDate: Date

    var id: String { path }

    var iconName: String {
        if isDirectory { return "folder.fill" }
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "png", "jpg", "jpeg", "heic", "webp", "gif": return "photo"
        case "mp4", "mov", "m4v":                          return "film"
        case "mp3", "m4a", "wav", "aac":                   return "music.note"
        case "plist":                                       return "doc.text"
        case "db", "sqlite", "sqlite3":                    return "cylinder"
        case "dylib", "framework":                         return "shippingbox"
        case "zip", "tar", "gz":                           return "doc.zipper"
        case "ttf", "otf", "ttc":                          return "textformat"
        case "pdf":                                        return "doc.richtext"
        default:                                           return "doc"
        }
    }

    var formattedSize: String {
        if isDirectory { return "" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f.string(from: modificationDate)
    }
}

extension Array where Element == FileEntry {
    func sorted(by order: SortOrder) -> [FileEntry] {
        sorted { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            switch order {
            case .name: return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            case .date: return a.modificationDate > b.modificationDate
            case .size: return a.size > b.size
            case .type:
                let extA = (a.name as NSString).pathExtension
                let extB = (b.name as NSString).pathExtension
                return extA.localizedCaseInsensitiveCompare(extB) == .orderedAscending
            }
        }
    }
}

enum SortOrder {
    case name, date, size, type
}

struct ConflictItem: Identifiable {
    let id = UUID()
    let name: String
    let sourceURL: URL
    let destinationPath: String
}

enum ConflictAction {
    case replace, keepBoth, skip
}

// MARK: - Document picker wrapper

struct DocumentPickerView: UIViewControllerRepresentable {
    var contentTypes: [UTType] = [.item]
    var mode: Mode = .import_
    var urls: [URL] = []
    var onPick: ([URL]) -> Void

    enum Mode { case import_, export }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker: UIDocumentPickerViewController
        switch mode {
        case .import_:
            picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
            picker.allowsMultipleSelection = true
        case .export:
            picker = UIDocumentPickerViewController(forExporting: urls)
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void
        init(onPick: @escaping ([URL]) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }
    }
}
