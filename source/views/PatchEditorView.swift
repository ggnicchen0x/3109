import SwiftUI

struct PatchEditorView: View {
    @EnvironmentObject var patchStore: PatchProjectStore
    @EnvironmentObject var patchDraftCoordinator: PatchDraftCoordinator
    @EnvironmentObject var fileOperationCoordinator: FileOperationCoordinator

    @State private var projects: [PatchProject] = []
    @State private var selectedProject: PatchProject?
    @State private var showNewProject = false
    @State private var newProjectName = ""

    var body: some View {
        NavigationView {
            List {
                if projects.isEmpty {
                    Text("No patch projects")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(projects) { project in
                        NavigationLink {
                            PatchDetailView(project: project)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(project.name)
                                    .font(.body)
                                HStack {
                                    Text("\(project.entries.count) entries")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(project.modifiedAt, style: .relative)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete { indices in
                        for idx in indices {
                            patchStore.delete(projects[idx].id)
                        }
                        refresh()
                    }
                }
            }
            .navigationTitle("Patches")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showNewProject = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("New Patch Project", isPresented: $showNewProject) {
                TextField("Name", text: $newProjectName)
                Button("Create") {
                    patchStore.create(name: newProjectName)
                    newProjectName = ""
                    refresh()
                }
                Button("Cancel", role: .cancel) {}
            }
            .onAppear { refresh() }
        }
    }

    private func refresh() {
        projects = patchStore.allProjects()
    }
}

struct PatchDetailView: View {
    let project: PatchProject

    var body: some View {
        List {
            Section("Info") {
                LabeledContent("Name", value: project.name)
                LabeledContent("Created", value: project.createdAt, format: .dateTime)
            }

            Section("Entries") {
                if project.entries.isEmpty {
                    Text("No entries")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(project.entries) { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.targetPath)
                                .font(.body.monospaced())
                                .lineLimit(1)
                            Text(entry.action.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(project.name)
    }
}

// MARK: - Models

struct PatchProject: Identifiable, Codable {
    let id: UUID
    var name: String
    var entries: [PatchEntry]
    let createdAt: Date
    var modifiedAt: Date
}

struct PatchEntry: Identifiable, Codable {
    let id: UUID
    let targetPath: String
    let action: PatchAction
    let sourcePath: String?
    let plistKey: String?
    let plistValue: String?
}

enum PatchAction: String, Codable {
    case copy
    case delete
    case mkdir
    case plistSet
    case plistDelete
    case symlink
    case move
}
