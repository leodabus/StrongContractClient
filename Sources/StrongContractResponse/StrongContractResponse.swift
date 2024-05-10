// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import Callable
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public var defaultComponents: URLComponents = .init()
public var defaultPath: String?
public var defaultContentType: String = ""

/// **What is it**: 
///     `Request` is a type intended to be shared on both client and server side to create strong contracts
///
/// **Problem `Request` solves**:
///     Instead of creating a path on the server side, converting types back and forth with `JSON`, creating swagger documents,
///     Then meetings with server side and client side devs to "sync" up, and errors where incorrect payloads are sent to
///     to the server, and client side devs are unsure exactly what values are required by the server side, and not sure what to
///     expect as a response.
///
/// **Set up**:
///     - Import `StrongContractClient` into both the client side app and the server side project.
///
/// **How to use**:
///     1. Create an instance of `Request` assigning the type of the payload you want to send from client to server `Payload` and
///     the type you intend for the server to respond back with `Response`.  Suppose we call our instance of request: `register`
///     2. Make a call to `task` on the client side with your instance: `Request.register.task(` The method will know what payload
///     and response types thanks to the Swift Compiler's Generic type inference.
///     3. Make a call to `registerHandler` on the server side with your instance: `Request.register.registerHandler(`
///     The method will know what payload and response types thanks to the Swift Compiler's Generic type inference.
///
/// **How to modify**:
///     *Change to the payload the client sends and the server side receives*:  Simply make a change to the `Payload` type
///     assigned to your request. merge the changes, create a release, then both client and server update packages.
///     *Change to the response the server sends and the client side receives*:  Simply make a change to the `Response` type
///     assigned to your request, merge the changes, create a release, then both client and server update packages.
///
/// - Parameters:
///   - payload: Payload is the type your request instance sends to the server side.  If you don't need to send anything then
///   you can use the `Empty` type.  That way the corresponding `task` and `registerHandler` can omit the payload.
///   - response: The `Response` type is the type that the server returns to the client.
public struct Request<Payload: Codable, Response: Codable> {

    public var path: String
    public var method: HTTPMethod
    public var baseComponents: URLComponents = defaultComponents
    public var initialPath: String = .theBaseURL
    public var contentType: String = defaultContentType
    public var token: String?


    /// Initializer
    /// - Parameters:
    ///   - path: A string for the path.  The default argument makes the path the same as the property of function calling it.
    ///   This defaults to `#function` so that the path is unique as the static properties shouldn't overlap.  This also improves the syntax.
    ///   - method: The HTTPMethod of the request.
    ///   - baseComponents: The base components
    ///   - initialPath: The defualt base url.
    ///   - mimType: MimType, default is JSON
    ///   - token: access Token.
    public init(
        path: String = #function,
        method: HTTPMethod,
        baseComponents: URLComponents = defaultComponents,
        initialPath: String = String.theBaseURL,
        mimType: MimeType = .json,
        token: String? = nil
    ) {
        self.path = path
        self.method = method
        self.baseComponents = baseComponents
        self.initialPath = initialPath
        self.contentType = mimType.rawValue
        self.token = token
    }

    /// Request initailizer.
    /// - Parameters:
    ///   - path: A string for the path.  The default argument makes the path the same as the property of function calling it.
    ///   This defaults to `#function` so that the path is unique as the static properties shouldn't overlap.  This also improves the syntax.
    ///   - method: The HTTPMethod of the request.
    ///   - baseComponents: The base components
    ///   - initialPath: The defualt base url.
    ///   - contentType: content type
    ///   - token: access Token.
    public init(
        path: String = #function,
        method: HTTPMethod,
        baseComponents: URLComponents = defaultComponents,
        initialPath: String = String.theBaseURL,
        contentType: String,
        token: String? = nil
    ) {
        self.path = path
        self.method = method
        self.baseComponents = baseComponents
        self.initialPath = initialPath
        self.contentType = contentType
        self.token = token
    }

    public typealias PassResponse = (Response?) -> Void

    enum URLRequestCreationError: Error {
        case malformedURL(String)
        case otherError(String)
    }

    /// This is made to be a force unwrap so that the user of this framework may write unit tests.
    public func urlRequest(payload: Payload?, using encoder: JSONEncoder = .init()) throws -> URLRequest {
        
        // Combine the base components with the initial and specific path
        var components = baseComponents
        let fullPath = "/\(initialPath)/\(path)".replacingOccurrences(of: "//", with: "/")
        // Ensures no leading double slashes
        components.path = fullPath
        // Attempt to validate the URL and create the URLRequest
        let url = try components.urlAndValidate()
        // Create the URLRequest and set its properties
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        if let token {
            request.setValue( "Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.addValue(contentType, forHTTPHeaderField: "Content-Type")
        // ... Set other properties on the request as needed ...
        if let payload {
            request.httpBody = try encoder.encode(payload)
        }
        //assert(<#T##condition: Bool##Bool#>)
        return request
    }

    /// This is the client side half of the strong contract between the client and the api
    /// You can call this task and trust that the
    /// - Parameters:
    ///   - expressive: Prints any errors.
    ///   - payload: The payload you want to pass to the backend.
    ///   - passResponse: Exposes the response from the backend.
    ///   - errorHandler: Exposes any errors, including non async errors.  Errors can come from failed url validation of urlComponents, failing to encode the payload into the request body, and any errors produced when creating a session and making a datatask on the URLRequest.
    @discardableResult
    public func task(
        autoResume: Bool = true,
        expressive: Bool = false,
        assertHasAccessToken: Bool = true,
        payload: Payload,
        passResponse: @escaping PassResponse = { _ in },
        errorHandler: ErrorHandler? = nil
    ) -> URLSessionDataTask? {
        print("assertHasAccessToken:", assertHasAccessToken)
        if assertHasAccessToken {
            print("token:", token ?? "nil")
            assert(token != "")
        }
        print("Starting new task with payload:\n", payload)
        do {
            let newTask = try urlRequest(payload: payload)
                .callCodableErrorTask(
                    expressive: expressive,
                    action: passResponse,
                    errorHandler: errorHandler
                )
            if autoResume {
                newTask.resume()
            }
            return newTask
        } catch {
            print("URLSession failed with error:", error)
            errorHandler?(error)
            return nil
        }
    }
}

extension Request where Payload == Empty {

    /// Helper function for when the payload is empty, this makes it so you don't have to pass payload as an argument.
    /// - Parameters:
    ///   - expressive: Prints any errors.
    ///   - assertHasAccessToken: asserts there is an access token.
    ///   - passResponse: Exposes the response from the backend.
    ///   - errorHandler: Exposes any errors, including non async errors.  Errors can come from failed url validation of urlComponents, failing to encode the payload into the request body, and any errors produced when creating a session and making a datatask on the URLRequest.
    public func task(
        expressive: Bool = false,
        assertHasAccessToken: Bool = true,
        passResponse: @escaping PassResponse = { _ in },
        errorHandler: ErrorHandler? = nil
    ) {
        self.task(
            expressive: expressive,
            assertHasAccessToken: assertHasAccessToken,
            payload: Empty(),
            passResponse: passResponse,
            errorHandler: errorHandler
        )
    }
}
