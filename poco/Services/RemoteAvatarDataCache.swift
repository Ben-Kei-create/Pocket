import Foundation

actor RemoteAvatarDataCache {
    static let shared = RemoteAvatarDataCache()

    private var cachedData: [URL: Data] = [:]
    private var cacheOrder: [URL] = []
    private var inFlight: [URL: Task<Data?, Never>] = [:]
    private let maximumEntryCount = 100
    private let maximumCacheBytes = 32 * 1_024 * 1_024
    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        session = URLSession(configuration: configuration)
    }

    func data(for url: URL, maximumBytes: Int = 2_097_152) async -> Data? {
        guard RemoteAssetPolicy.isAllowed(url), maximumBytes > 0 else { return nil }
        if let data = cachedData[url] {
            cacheOrder.removeAll { $0 == url }
            cacheOrder.append(url)
            return data.count <= maximumBytes ? data : nil
        }
        if let task = inFlight[url] {
            let data = await task.value
            return data?.count ?? 0 <= maximumBytes ? data : nil
        }

        let session = session
        let task = Task<Data?, Never> {
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("image/jpeg", forHTTPHeaderField: "Accept")

                let (bytes, response) = try await session.bytes(for: request)
                guard let response = response as? HTTPURLResponse,
                      (200..<300).contains(response.statusCode),
                      response.mimeType == "image/jpeg",
                      response.expectedContentLength <= Int64(maximumBytes),
                      let finalURL = response.url,
                      RemoteAssetPolicy.isAllowed(finalURL) else { return nil }

                var data = Data()
                if response.expectedContentLength > 0 {
                    data.reserveCapacity(Int(response.expectedContentLength))
                }
                for try await byte in bytes {
                    guard data.count < maximumBytes else { return nil }
                    data.append(byte)
                }
                return data
            } catch {
                return nil
            }
        }
        inFlight[url] = task
        let data = await task.value
        inFlight[url] = nil

        if let data {
            cacheOrder.removeAll { $0 == url }
            while cachedData.count >= maximumEntryCount
                || cachedData.values.reduce(0, { $0 + $1.count }) + data.count
                    > maximumCacheBytes {
                guard let oldestKey = cacheOrder.first else { break }
                cacheOrder.removeFirst()
                cachedData[oldestKey] = nil
            }
            cachedData[url] = data
            cacheOrder.append(url)
        }
        return data
    }
}

nonisolated enum RemoteAssetPolicy {
    static func isAllowed(_ url: URL, bundle: Bundle = .main) -> Bool {
        let configuration = AppConfiguration.load(from: bundle)
        guard url.scheme?.lowercased() == "https",
              url.user == nil,
              url.password == nil,
              let expectedHost = configuration.supabaseURL?.host?.lowercased(),
              url.host?.lowercased() == expectedHost else { return false }

        let path = url.path.lowercased()
        return path.contains("/storage/v1/object/public/profile-avatars/")
            || path.contains("/storage/v1/object/public/project-images/")
    }
}
