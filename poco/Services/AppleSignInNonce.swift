import CryptoKit
import Foundation
import Security

enum AppleSignInNonce {
    private static let characters = Array(
        "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._"
    )

    static func make(length: Int = 32) -> String {
        precondition(length > 0)
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)

        guard status == errSecSuccess else {
            return UUID().uuidString.replacingOccurrences(of: "-", with: "")
        }

        return String(bytes.map { characters[Int($0) % characters.count] })
    }

    static func hash(_ nonce: String) -> String {
        let digest = SHA256.hash(data: Data(nonce.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
