//
//  Sequence.swift
//
//
//  Created by lsd on 07/05/24.
//

extension Sequence where Element == UInt8 {
    
    var string: String? {
        .init(bytes: self, encoding: .utf8)
    }
    
    var hexa: String {
        map { String(format: "%02hhx", $0) }.joined()
    }
}
