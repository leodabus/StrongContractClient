//
//  DataProtocol.swift
//
//
//  Created by Leonardo Dabus on 10/05/24.
//

import Foundation

#if canImport(Crypto)
import Crypto
#endif

#if canImport(CryptoKit)
import CryptoKit
#endif

extension DataProtocol {
    var sha256digest: SHA256Digest { SHA256.hash(data: self) }
    var sha384digest: SHA384Digest { SHA384.hash(data: self) }
    var sha512digest: SHA512Digest { SHA512.hash(data: self) }
}
