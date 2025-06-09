import Foundation

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
    let url = URL(string: "https://api.github.com")!
        .appending(components: "repos", org, repo, "releases", "latest")
    let request = URLRequest(url: url)

    let (data, response) = try await URLSession.shared.data(for: request)

    guard
        let httpResponse = response as? HTTPURLResponse,
        200 ..< 300 ~= httpResponse.statusCode
    else {
        fatalError("invalid response")
    }

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase

    let latest = try decoder.decode(Release.self, from: data)
    return latest
}
