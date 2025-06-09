import ArgumentParser
import Basics
import CryptoKit
import Foundation
import PackageModel
import Workspace

struct GenericError: LocalizedError {
    let errorDescription: String
}

struct BinaryDependency {
    let name: String
    let url: URL
    let checksum: String
}

@main
struct BuildPluginUpdater: AsyncParsableCommand {
    @Argument(transform: RelativePath.init(validating:))
    var packagePath: RelativePath

    mutating func run() async throws {
        let workingDirectory = try AbsolutePath(validating: FileManager.default.currentDirectoryPath)
        let packagePath = workingDirectory.appending(packagePath)

        let observability = ObservabilitySystem({ print("[SwiftPM] \($0): \($1)") })
        let workspace = try Workspace(forRootPackage: packagePath)
        let manifest = try await workspace.loadRootManifest(at: packagePath, observabilityScope: observability.topScope)

        let binaryDependencies = try await withThrowingTaskGroup(of: BinaryDependency.self) { group in
            for target in manifest.targets where target.type == .binary {
                guard let url = target.url else {
                    continue
                }

                group.addTask {
                    let (org, repo) = parseRepoURL(url)
                    let latestRelease = try await findLatestRelease(org: org, repo: repo)

                    print("found latest release for \(target.name): \(latestRelease.tagName)")

                    guard let artifactBundleUrl = findArtifactBundle(in: latestRelease) else {
                        throw GenericError(errorDescription: "cannot find artifact bundle for \(target.name) in \(latestRelease.tagName)")
                    }

                    let checksum = try Data(contentsOf: artifactBundleUrl).sha256
                    return BinaryDependency(name: target.name, url: artifactBundleUrl, checksum: checksum)
                }
            }

            var results: [BinaryDependency] = []

            for try await dependency in group {
                results.append(dependency)
            }

            return results
        }

        var targets = manifest.targets.filter { $0.type != .binary }
        for dependency in binaryDependencies.sorted(using: KeyPathComparator(\.name)) {
            try targets.append(.init(
                name: dependency.name,
                url: dependency.url.absoluteString,
                type: .binary,
                checksum: dependency.checksum
            ))
        }

        let updatedManifest = Manifest(
            displayName: manifest.displayName,
            path: manifest.path,
            packageKind: manifest.packageKind,
            packageLocation: manifest.packageLocation,
            defaultLocalization: manifest.defaultLocalization,
            platforms: manifest.platforms,
            version: manifest.version,
            revision: manifest.revision,
            toolsVersion: manifest.toolsVersion,
            pkgConfig: manifest.pkgConfig,
            providers: manifest.providers,
            cLanguageStandard: manifest.cLanguageStandard,
            cxxLanguageStandard: manifest.cxxLanguageStandard,
            swiftLanguageVersions: manifest.swiftLanguageVersions,
            dependencies: manifest.dependencies,
            products: manifest.products,
            targets: targets
        )

        let manifestContent = try updatedManifest.generateManifestFileContents(packageDirectory: packagePath)
        try manifestContent.write(to: packagePath.asURL.appending(component: "Package.swift"), atomically: true, encoding: .utf8)

        print("Updated manifest file at \(packagePath.asURL.appending(component: "Package.swift").path())")
    }
}

private func findArtifactBundle(in release: Release) -> URL? {
    release.assets.first(where: { $0.name.hasSuffix(".artifactbundle.zip") })?.browserDownloadUrl
}

private func parseRepoURL(_ url: String) -> (org: String, repo: String) {
    guard let components = URLComponents(string: url) else {
        fatalError()
    }

    let pathComponents = components.path.split(separator: "/")
    return (org: String(pathComponents[0]), repo: String(pathComponents[1]))
}
