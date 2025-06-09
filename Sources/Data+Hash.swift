//
//  Data+Hash.swift
//  update
//
//  Created by Vladimir Burdukov on 04/10/2024.
//

import Foundation
import CryptoKit

extension Data {
    func checksum<H: HashFunction>(_ hashFunction: H.Type) -> String {
        let hashData = hashFunction.hash(data: self)

        var hashString = ""
        hashString.reserveCapacity(hashFunction.Digest.byteCount * 2)

        for byte in hashData {
            if byte < 0x10 {
                hashString.append("0")
            }

            hashString.append(String(byte, radix: 16, uppercase: false))
        }

        return hashString
    }

    public var md5: String {
        checksum(Insecure.MD5.self)
    }

    public var sha1: String {
        checksum(Insecure.SHA1.self)
    }

    public var sha256: String {
        checksum(SHA256.self)
    }
}
