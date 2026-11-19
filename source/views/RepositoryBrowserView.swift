import SwiftUI

struct RepositoryBrowserView: View {
    @EnvironmentObject var repositoryStore: PackageRepositoryStore

    @State private var repos: [PackageRepository] = []
    @State private var selectedRepo: PackageRepository?
    @State private var showAddRepo = false
    @State private var addRepoURL = ""
    @State private var packages: [RepositoryPackage] = []
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            List {
                Section("Repositories") {
                    ForEach(repos) { repo in
                        Button {
                            selectedRepo = repo
                            loadPackages(repo)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(repo.name)
                                    .font(.body)
                                Text(repo.url.absoluteString)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .onDelete { indices in
                        for idx in indices {
                            repositoryStore.remove(repos[idx].id)
                        }
                        refresh()
                    }
                }

                if let repo = selectedRepo {
                    Section("Packages — \(repo.name)") {
                        if isLoading {
                            HStack {
                                ProgressView()
                                Text("Loading...")
                                    .foregroundColor(.secondary)
                            }
                        } else if packages.isEmpty {
                            Text("No packages")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(packages) { pkg in
                                NavigationLink {
                                    PackageDetailView(package: pkg)
                                } label: {
                                    HStack {
                                        AsyncImage(url: pkg.iconURL) { image in
                                            image.resizable()
                                        } placeholder: {
                                            Image(systemName: "shippingbox")
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(width: 40, height: 40)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(pkg.name)
                                                .font(.body)
                                            Text(pkg.author)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text(pkg.shortDescription)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Repositories")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddRepo = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("Add Repository", isPresented: $showAddRepo) {
                TextField("Repository URL", text: $addRepoURL)
                Button("Add") {
                    if let url = URL(string: addRepoURL) {
                        repositoryStore.add(name: url.host ?? "Repo", url: url)
                        addRepoURL = ""
                        refresh()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .onAppear { refresh() }
        }
    }

    private func refresh() {
        repos = repositoryStore.allRepositories()
    }

    private func loadPackages(_ repo: PackageRepository) {
        isLoading = true
        packages = []
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: repo.url)
                let decoded = try JSONDecoder().decode([RepositoryPackage].self, from: data)
                await MainActor.run {
                    packages = decoded
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    AppNoticeCenter.shared.postError(error)
                }
            }
        }
    }
}

struct PackageDetailView: View {
    let package: RepositoryPackage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    AsyncImage(url: package.iconURL) { image in
                        image.resizable()
                    } placeholder: {
                        Image(systemName: "shippingbox")
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading) {
                        Text(package.name)
                            .font(.title2.bold())
                        Text(package.author)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("v\(package.version)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Text(package.description)
                    .font(.body)

                if let downloadURL = package.downloadURL {
                    Button {
                        // Trigger download and install
                    } label: {
                        Text("Install")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(16)
        }
        .navigationTitle(package.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Models

struct PackageRepository: Identifiable, Codable {
    let id: UUID
    let name: String
    let url: URL
    let addedAt: Date
}

struct RepositoryPackage: Identifiable, Codable {
    let id: String
    let name: String
    let author: String
    let version: String
    let description: String
    let shortDescription: String
    let iconURL: URL?
    let downloadURL: URL?
}
