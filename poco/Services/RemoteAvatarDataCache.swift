import Foundation

actor RemoteAvatarDataCache {
    static let shared = RemoteAvatarDataCache()

    private var cachedData: [URL: Data] = [:]
    private var inFlight: [URL: Task<Data?, Never>] = [:]
    private let maximumEntryCount = 100

    func data(for url: URL) async -> Data? {
        if let data = cachedData[url] {
            return data
        }
        if let task = inFlight[url] {
            return await task.value
        }

        let task = Task<Data?, Never> {
            guard let (data, response) = try? await URLSession.shared.data(from: url),
                  let response = response as? HTTPURLResponse,
                  (200..<300).contains(response.statusCode),
                  data.count <= 2_097_152 else { return nil }
            return data
        }
        inFlight[url] = task
        let data = await task.value
        inFlight[url] = nil

        if let data {
            if cachedData.count >= maximumEntryCount,
               let oldestKey = cachedData.keys.first {
                cachedData[oldestKey] = nil
            }
            cachedData[url] = data
        }
        return data
    }
}
