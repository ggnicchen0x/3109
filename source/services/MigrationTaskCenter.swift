import Foundation
import Combine

final class MigrationTaskCenter: ObservableObject {

    @Published var activeTasks: [MigrationTask] = []
    @Published var isRunning: Bool = false
    @Published var completedCount: Int = 0

    struct MigrationTask: Identifiable {
        let id: UUID
        let name: String
        let source: URL
        let destination: URL
        var progress: Double
        var isComplete: Bool
        var error: String?
    }

    private let engine = MigrationEngine()
    private let queue = DispatchQueue(label: "5013.migration.tasks", qos: .userInitiated)

    func enqueue(name: String, source: URL, destination: URL) {
        let task = MigrationTask(
            id: UUID(), name: name, source: source, destination: destination,
            progress: 0.0, isComplete: false
        )
        activeTasks.append(task)
    }

    func run() {
        guard !isRunning, !activeTasks.isEmpty else { return }
        isRunning = true
        completedCount = 0

        queue.async { [weak self] in
            self?.executeNext()
        }
    }

    func cancelAll() {
        engine.cancel()
        isRunning = false
    }

    private func executeNext() {
        guard let idx = activeTasks.firstIndex(where: { !$0.isComplete && $0.error == nil }) else {
            DispatchQueue.main.async { [weak self] in
                self?.isRunning = false
            }
            return
        }

        let task = activeTasks[idx]
        do {
            let plan = try engine.buildPlan(source: task.source, destination: task.destination)
            engine.execute(plan: plan) { [weak self] progress in
                DispatchQueue.main.async {
                    self?.activeTasks[idx].progress = progress
                }
            }

            // Wait for completion
            while engine.state != .completed && engine.state != .idle {
                if case .failed(let msg) = engine.state {
                    DispatchQueue.main.async { [weak self] in
                        self?.activeTasks[idx].error = msg
                    }
                    break
                }
                Thread.sleep(forTimeInterval: 0.1)
            }

            DispatchQueue.main.async { [weak self] in
                self?.activeTasks[idx].isComplete = true
                self?.activeTasks[idx].progress = 1.0
                self?.completedCount += 1
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.activeTasks[idx].error = error.localizedDescription
            }
        }

        executeNext()
    }
}
