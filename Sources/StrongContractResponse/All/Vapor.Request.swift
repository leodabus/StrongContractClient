//
//  File.swift
//  
//
//  Created by Scott Lydon on 4/7/24.
//

#if canImport(Vapor)
//import EncryptDecryptKey
import Vapor
import Callable

extension Vapor.Request {


    func codableBody<T: Codable>() throws -> T {
        guard let bodyData = body.data else { throw GenericError(text: "Body data was nil") }
        return try JSONDecoder().decode(T.self, from: bodyData.data)
    }

    func codableBodyExemptingData<T: Codable>() throws -> T {
        if T.self == Data.self, let data = body.data?.data as? T {
            return data
        } else if let bodyData = body.data {
            return try JSONDecoder().decode(T.self, from: bodyData.data)
        }
        throw GenericError(text: "Body data was nil")
    }
}
#endif
