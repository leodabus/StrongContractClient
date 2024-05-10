//
//  File.swift
//  
//
//  Created by Scott Lydon on 4/6/24.
//
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Needs an extension for Codable.
extension URLQueryItem: Codable {
    private enum CodingKeys: String, CodingKey {
        case name, value
    }

    /// If this passes a Unit test, then it is safe.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // we are decoding the value which was coded prior
        let name: String = try container.decode(String.self, forKey: .name)
        // We are decoding the value which was coded prior.
        let value: String? = try container.decodeIfPresent(String.self, forKey: .value)
        self.init(name: name, value: value)
    }

    /// If this passes a unit test, then this is safe.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name) // we are encoding the property
        try container.encodeIfPresent(value, forKey: .value) // and the second property.
    }
}
