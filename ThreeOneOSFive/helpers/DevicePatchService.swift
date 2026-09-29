import Foundation

enum DevicePatchService {
    static func apply(project: PatchProject, targetBundleID: String? = nil) throws -> PatchTransactionReceipt {
        let activeProject = targetBundleID != nil ? remapProject(project, to: targetBundleID!) : project
        let bundleIDs = orderedBundleIdentifiers(in: activeProject)
        return try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            try PatchTransaction.apply(
                project: activeProject,
                backupRoot: try PatchProjectLibrary.backupRootURL(),
                containerResolver: { bundleID in
                    guard let root = roots[bundleID] else {
                        throw PatchPackageError.targetAppUnavailable(bundleID)
                    }
                    return root
                }
            )
        }
    }

    private static func remapProject(_ project: PatchProject, to targetBundleID: String) -> PatchProject {
        guard targetBundleID.caseInsensitiveCompare("com.dts.freefireth") != .orderedSame else { return project }
        let sourceBundle = "com.dts.freefireth"

        let newRules = project.rules.map { rule -> PatchRule in
            var r = rule
            if r.bundleID.caseInsensitiveCompare(sourceBundle) == .orderedSame {
                r.bundleID = targetBundleID
                if r.relativePath.contains("com.dts.freefireth.plist") {
                    r.relativePath = r.relativePath.replacingOccurrences(of: "com.dts.freefireth.plist", with: "\(targetBundleID).plist")
                }
            }
            return r
        }

        let newDirectories = project.directories.map { dir -> PatchDirectory in
            var d = dir
            if d.bundleID.caseInsensitiveCompare(sourceBundle) == .orderedSame {
                d.bundleID = targetBundleID
            }
            return d
        }

        let newBundles = project.bundleIdentifiers.map { bid in
            bid.caseInsensitiveCompare(sourceBundle) == .orderedSame ? targetBundleID : bid
        }

        return PatchProject(
            id: project.id,
            name: project.name,
            createdAt: project.createdAt,
            updatedAt: project.updatedAt,
            bundleIdentifiers: newBundles.isEmpty ? [targetBundleID] : newBundles,
            directories: newDirectories,
            rules: newRules
        )
    }

    static func restore(receipt: PatchTransactionReceipt) throws {
        let bundleIDs = try PatchTransaction.requiredBundleIdentifiers(for: receipt)
        try withResolvedContainers(bundleIDs: bundleIDs) { roots in
            try PatchTransaction.restore(
                receipt: receipt,
                containerResolver: { bundleID in
                    guard let root = roots[bundleID] else {
                        throw PatchPackageError.targetAppUnavailable(bundleID)
                    }
                    return root
                }
            )
        }
    }

    /// Desliga de verdade: devolve os arquivos do backup, no mesmo fluxo do Hs Alto / Hs pescoco.
    static func deactivate(projectID: UUID) {
        guard let backupRoot = try? PatchProjectLibrary.backupRootURL() else { return }
        let receipt = PatchTransaction.latestReceipt(projectID: projectID, backupRoot: backupRoot)
            ?? PatchTransaction.latestRestoreReceipt(projectID: projectID, backupRoot: backupRoot)
        guard let receipt else { return }
        do {
            try restore(receipt: receipt)
        } catch {
            log("patch: deactivate restore: \(error.localizedDescription)")
        }
    }

    /// Pacotes com toggle OFF nao podem ficar injetados ao abrir o app.
    static func uninjectInactivePackages(items: [PatchLibraryItem]) {
        let inactiveIDs = items.compactMap { item -> UUID? in
            latestReceipt(projectID: item.id) == nil ? item.id : nil
        }
        guard let backupRoot = try? PatchProjectLibrary.backupRootURL() else { return }
        for receipt in PatchTransaction.latestRestoreReceiptsNewestFirst(
            projectIDs: inactiveIDs,
            backupRoot: backupRoot
        ) {
            do {
                try restore(receipt: receipt)
            } catch {
                log("patch: startup uninject: \(error.localizedDescription)")
            }
        }
    }

    static func latestReceipt(projectID: UUID) -> PatchTransactionReceipt? {
        guard let backupRoot = try? PatchProjectLibrary.backupRootURL() else { return nil }
        return PatchTransaction.latestReceipt(projectID: projectID, backupRoot: backupRoot)
    }

    private static func orderedBundleIdentifiers(in project: PatchProject) -> [String] {
        project.allBundleIdentifiers
    }

    private static func withResolvedContainers<T>(
        bundleIDs: [String],
        operation: ([String: URL]) throws -> T
    ) throws -> T {
        var roots: [String: URL] = [:]

        for bundleID in bundleIDs {
            // Se o app nao estiver instalado, pula — nao lanca erro
            guard let path = ContainerStore.resolveAppContainerPath(bundleID: bundleID),
                  ContainerStore.isApplicationContainerPath(path) else {
                continue
            }
            roots[bundleID] = PatchPathValidator.canonicalFileURL(URL(fileURLWithPath: path, isDirectory: true))
        }

        // Se nenhum app foi encontrado, ai sim lanca erro
        guard !roots.isEmpty else {
            throw PatchPackageError.targetAppUnavailable(bundleIDs.first ?? "unknown")
        }

        return try operation(roots)
    }
}
