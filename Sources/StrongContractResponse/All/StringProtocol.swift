//
//  File.swift
//  
//
//  Created by lsd on 07/05/24.
//

import Foundation
//
//  File.swift
//
//
//  Created by Leonardo Dabus on 04/07/21.
//

import Foundation
import protocol Foundation.DataProtocol
import protocol Foundation.ContiguousBytes
import struct Foundation.Data

#if canImport(Crypto)
import Crypto
#endif

#if canImport(CryptoKit)
import CryptoKit
#endif

extension StringProtocol {

    var data: Data { .init(utf8) }
    var hexaData: Data { .init(hexa) }
    var hexaBytes: [UInt8] { .init(hexa) }

    private var hexa: UnfoldSequence<UInt8, Index> {
        sequence(state: startIndex) { startIndex in
            guard startIndex < self.endIndex else { return nil }
            let endIndex = self.index(startIndex, offsetBy: 2, limitedBy: self.endIndex) ?? self.endIndex
            defer { startIndex = endIndex }
            return UInt8(self[startIndex..<endIndex], radix: 16)
        }
    }

    var sha256hexa: String { data.sha256digest.hexa }
    var sha384hexa: String { data.sha384digest.hexa }
    var sha512hexa: String { data.sha512digest.hexa }
}
