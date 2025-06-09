//
//  FindLatestVersion.swift
//  update
//
//  Created by Vladimir Burdukov on 03/10/2024.
//

import Foundation
import Security

struct Release: Decodable {
    let id: Int
    let tagName: String
    let assets: [Asset]
}

struct Asset: Decodable {
    let id: Int
    let name: String
    let browserDownloadUrl: URL
}

func findLatestRelease(org: String, repo: String) async throws -> Release {
    let token = try getGithubToken()

    let url = try URL("https://api.github.com", strategy: .url)
        .appending(components: "repos", org, repo, "releases", "latest")
    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await URLSession.shared.data(for: request)
    let httpResponse = response as! HTTPURLResponse

    guard 200 ..< 300 ~= httpResponse.statusCode else {
        fatalError("unexpected response code \(httpResponse.statusCode)")
    }

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase

    let latest = try decoder.decode(Release.self, from: data)
    return latest
}

private struct KeychainError: LocalizedError {
    let status: OSStatus

    var errorDescription: String? {
        guard let string = SecCopyErrorMessageString(status, nil) else {
            return nil
        }

        return string as String
    }
}

private func getGithubToken() throws -> String {
    if let env_token = ProcessInfo.processInfo.environment["GITHUB_TOKEN"] {
        return env_token
    } else {
        let result = try search(service: "github.com") as NSDictionary

        guard
            let tokenData = result[kSecValueData] as? Data,
            let token = String(bytes: tokenData, encoding: .utf8)
        else {
            fatalError("unable to get token from keychain response")
        }

        return token
    }
}

private func search(service: String) throws -> CFDictionary {
    var query = query(service: service, account: nil)
    query[kSecReturnAttributes] = true as CFBoolean
    query[kSecReturnData] = true as CFBoolean
    query[kSecMatchLimit] = 1 as CFNumber

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    guard status == errSecSuccess else {
        throw KeychainError(status: status)
    }

    if let result = result {
        return result as! CFDictionary
    } else {
        return [:] as CFDictionary
    }
}

private func query(service: String, account: String?) -> [CFString: CFTypeRef] {
    var query: [CFString: CFTypeRef] = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrService: service as CFString
    ]

    if let account = account {
        query[kSecAttrAccount] = account as CFString
    }

    return query
}
