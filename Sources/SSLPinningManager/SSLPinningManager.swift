import CryptoKit
import Foundation

public struct SSLPinningManager {
    private enum PinningError: Error {
        case noCertificatesFromServer
        case failedToGetPublicKey
        case failedToGetDataFromPublicKey
        case receivedWrongCertificate
    }

    private var pinnedKeyHashes: [String]
    private let rsa2048ASN1Header: [UInt8] = [
        0x30, 0x82, 0x01, 0x22, 0x30, 0x0D, 0x06, 0x09, 0x2A, 0x86, 0x48, 0x86,
        0xF7, 0x0D, 0x01, 0x01, 0x01, 0x05, 0x00, 0x03, 0x82, 0x01, 0x0F, 0x00
    ]

    public init(
        pinnedKeyHashes: [String]
    ) {
        self.pinnedKeyHashes = pinnedKeyHashes
    }

    public func validate(
        challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        do {
            let trust = try validateAndGetTrust(with: challenge)
            completionHandler(.useCredential, URLCredential(trust: trust))
        }
        catch {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    private func validateAndGetTrust(
        with challenge: URLAuthenticationChallenge
    ) throws -> SecTrust {
        guard
            let trust = challenge.protectionSpace.serverTrust,
            let trustCertificateChain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
            !trustCertificateChain.isEmpty
        else {
            throw PinningError.noCertificatesFromServer
        }

        for serverCertificate in trustCertificateChain {
            let publicKey = try getPublicKey(for: serverCertificate)
            let publicKeyHash = try getKeyHash(of: publicKey)

            if pinnedKeyHashes.contains(publicKeyHash) {
                return trust
            }
        }
        throw PinningError.receivedWrongCertificate
    }

    private func getPublicKey(
        for certificate: SecCertificate
    ) throws -> SecKey {
        let policy = SecPolicyCreateBasicX509()
        var trust: SecTrust?
        let trustCreationStatus = SecTrustCreateWithCertificates(
            certificate,
            policy,
            &trust
        )

        if let trust,
           trustCreationStatus == errSecSuccess,
           let publicKey = SecTrustCopyKey(trust)
        {
            return publicKey
        }
        else {
            throw PinningError.failedToGetPublicKey
        }
    }

    private func getKeyHash(of publicKey: SecKey) throws -> String {
        guard let publicKeyCFData = SecKeyCopyExternalRepresentation(publicKey, nil) else {
            throw PinningError.failedToGetDataFromPublicKey
        }

        let publicKeyData = (publicKeyCFData as NSData) as Data
        var publicKeyWithHeaderData = Data(rsa2048ASN1Header)
        publicKeyWithHeaderData.append(publicKeyData)
        let publicKeyHashData = Data(SHA256.hash(data: publicKeyWithHeaderData))
        return publicKeyHashData.base64EncodedString()
    }
}

