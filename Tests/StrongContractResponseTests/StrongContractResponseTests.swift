import XCTest
import Callable
@testable import StrongContractClient
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct MockResponse: Codable {
    var message: String
}

// A custom Encodable type that always fails during encoding
struct AlwaysFailingEncoder: Codable {
    func encode(to encoder: Encoder) throws {
        throw GenericError(text: "Always fails")
    }
}

// Example of a response type that uses AlwaysFailingEncoder
struct ErrorOnEncodeResponse: Codable {
    var message: String
    var failingPart: AlwaysFailingEncoder
}

extension Data {
    func decrypt() throws -> Data {
        return Data(self.reversed())
    }
}


// Custom error used in the extension, define it if not already defined
struct GenericError: Error, LocalizedError {
    var text: String
    var errorDescription: String? { return text }
}


class RequestTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Reset cached URL before each test
        String._cachedBaseURL = nil
        UserDefaults.standard.removeObject(forKey: "BaseURL")
    }

    override func tearDown() {
        // Clean up after each test
        String._cachedBaseURL = nil
        UserDefaults.standard.removeObject(forKey: "BaseURL")
        super.tearDown()
    }

    func testBaseURLCaching() {
        // Setup
        let expectedURL = "https://example.com"
        String._cachedBaseURL = expectedURL

        // Test
        let baseURL = String.theBaseURL

        // Verify
        XCTAssertEqual(baseURL, expectedURL, "Cached URL should be returned")
    }

    func testResponseAdaptorInitializationWithError() {
        // Setup
        let response = AlwaysFailingEncoder()
        // ErrorOnEncodeResponse(message: "This should fail", failingPart: AlwaysFailingEncoder())


        // Test
        XCTAssertThrowsError({
            _ = try StrongContractClient.Request<Empty, AlwaysFailingEncoder>.ResponseAdaptor(
                body: response
            )
        }, "The initializer should throw an error when encoding fails") { error in
            if let error = error as? GenericError {
                XCTAssertEqual(error.text, "Always fails", "The error message should indicate why the encoding failed")
            } else {
                XCTFail("Error thrown was not a GenericError as expected.")
            }
        }
    }

    func testBaseURLRetrievalFromUserDefaults() {
        // Setup
        let expectedURL = "https://example.com"
        UserDefaults.standard.set(expectedURL, forKey: "BaseURL")

        // Test
        let baseURL = String.theBaseURL

        // Verify
        XCTAssertEqual(baseURL, expectedURL, "Base URL should be retrieved from UserDefaults")
    }

    func testBaseURLRetrievalFailure() {
        // Test
        let baseURL = String.theBaseURL

        // Verify
        XCTAssertTrue(baseURL.isEmpty, "Should return an empty string if no base URL is set")
    }

    func testResponseAdaptorInitializationSuccess() {
        // Setup
        let response = MockResponse(message: "Success")
        let encoder = JSONEncoder()

        // Test
        XCTAssertNoThrow({
            let adaptor = try StrongContractClient.Request<Empty, MockResponse>.ResponseAdaptor(
                status: .ok,
                body: response,
                using: encoder
            )
            XCTAssertEqual(adaptor.status, .ok)
            XCTAssertEqual(adaptor.version, .http1_1)
            XCTAssertEqual(adaptor.headers, .defaultJson)
            XCTAssertNotNil(adaptor.data)
        }, "Initialization should succeed without throwing an error")
    }

    func testVaporResponseGeneration() {
        // Setup
        let response = MockResponse(message: "Test")
        let adaptor = try! StrongContractClient.Request<Empty, MockResponse>.ResponseAdaptor(
            body: response,
            using: JSONEncoder()
        )

        // Test
        let vaporResponse = adaptor.vaporResponse

        // Verify
        XCTAssertEqual(vaporResponse.status, .ok)
        XCTAssertEqual(vaporResponse.version, .http1_1)
        XCTAssertEqual(vaporResponse.headers["Content-Length"].first, String(adaptor.data.readableBytes))
        XCTAssertNotNil(vaporResponse.body)
    }

    func testEncodingDecodingURLQueryItem() {
        // Setup
        let queryItem = URLQueryItem(name: "key", value: "value")

        // Encode
        let encoder = JSONEncoder()
        guard let encodedData = try? encoder.encode(queryItem) else {
            XCTFail("Failed to encode URLQueryItem")
            return
        }

        // Decode
        let decoder = JSONDecoder()
        guard let decodedItem = try? decoder.decode(URLQueryItem.self, from: encodedData) else {
            XCTFail("Failed to decode URLQueryItem")
            return
        }

        // Assert
        XCTAssertEqual(decodedItem.name, queryItem.name, "Decoded item name should match the original")
        XCTAssertEqual(decodedItem.value, queryItem.value, "Decoded item value should match the original")
    }

    func testMissingScheme() {
        // Setup
        var components = URLComponents()
        components.host = "example.com"
        components.path = "/path"

        // Test and verify
        XCTAssertThrowsError(try components.urlAndValidate()) { error in
            XCTAssertEqual(error as? URLValidationError, .missingScheme("Current scheme: nil"))
        }
    }

    func testMissingHost() {
        // Setup
        var components = URLComponents()
        components.scheme = "https"
        components.path = "/path"

        // Test and verify
        XCTAssertThrowsError(try components.urlAndValidate()) { error in
            XCTAssertEqual(error as? URLValidationError, .missingHost("Current host: nil"))
        }
    }

    func testMissingPath() {
        // Setup
        var components = URLComponents()
        components.scheme = "https"
        components.host = "example.com"
        // Intentionally leaving path empty

        // Test and verify
        XCTAssertThrowsError(try components.urlAndValidate()) { error in
            XCTAssertEqual(error as? URLValidationError, .missingPath("Current path is emtpy"))
        }
    }

    func testInvalidPath() {
        // Setup
        var components = URLComponents()
        components.scheme = "https"
        components.host = "example.com"
        components.path = "noLeadingSlash"  // Invalid because it doesn't start with "/"

        // Test and verify
        XCTAssertThrowsError(try components.urlAndValidate()) { error in
            XCTAssertEqual(error as? URLValidationError, .invalidPath("Current path: noLeadingSlash"))
        }
    }

    func testMissingScheme2() {
        var components = URLComponents()
        components.host = "example.com"
        components.path = "/path"

        XCTAssertThrowsError(try components.urlAndValidate()) { error in
            XCTAssertEqual(error as? URLValidationError, .missingScheme("Current scheme: nil"))
            XCTAssertEqual((error as? URLValidationError)?.errorDescription, "Scheme component is missing. Current scheme: nil")
        }
    }

    func testMissingHost2() {
        var components = URLComponents()
        components.scheme = "https"
        components.path = "/path"

        XCTAssertThrowsError(try components.urlAndValidate()) { error in
            XCTAssertEqual(error as? URLValidationError, .missingHost("Current host: nil"))
            XCTAssertEqual((error as? URLValidationError)?.errorDescription, "Host component is missing. Current host: nil")
        }
    }

    func testMissingPath2() {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "example.com"

        XCTAssertThrowsError(try components.urlAndValidate()) { error in
            XCTAssertEqual(error as? URLValidationError, .missingPath("Current path is emtpy"))
            XCTAssertEqual((error as? URLValidationError)?.errorDescription, "Path component is missing. Current path is emtpy")
        }
    }

    func testInvalidPath2() {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "example.com"
        components.path = "noLeadingSlash"

        XCTAssertThrowsError(try components.urlAndValidate()) { error in
            XCTAssertEqual(error as? URLValidationError, .invalidPath("Current path: noLeadingSlash"))
            XCTAssertEqual((error as? URLValidationError)?.errorDescription, "Path component is invalid. It must start with '/'. Current path: noLeadingSlash")
        }
    }

    func testValidURLComponents() {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "example.com"
        components.path = "/path"

        XCTAssertNoThrow(try {
            let url = try components.urlAndValidate()
            XCTAssertEqual(url.absoluteString, "https://example.com/path")
        }())
    }

    func testValidURLComponents2() {
        // Setup
        var components = URLComponents()
        components.scheme = "https"
        components.host = "example.com"
        components.path = "/path"

        // Test and verify
        XCTAssertNoThrow(try {
            let url = try components.urlAndValidate()
            XCTAssertEqual(url.absoluteString, "https://example.com/path")
        }())
    }

    func testEncodingDecodingURLQueryItemWithNilValue() {
        // Setup
        let queryItem = URLQueryItem(name: "key", value: nil)

        // Encode
        let encoder = JSONEncoder()
        guard let encodedData = try? encoder.encode(queryItem) else {
            XCTFail("Failed to encode URLQueryItem with nil value")
            return
        }

        // Decode
        let decoder = JSONDecoder()
        guard let decodedItem = try? decoder.decode(URLQueryItem.self, from: encodedData) else {
            XCTFail("Failed to decode URLQueryItem with nil value")
            return
        }

        // Assert
        XCTAssertEqual(decodedItem.name, queryItem.name, "Decoded item name should match the original")
        XCTAssertNil(decodedItem.value, "Decoded item value should be nil")
    }

    func testEmptyInit() {
        XCTAssertNotNil(Empty())
    }

    //        func testBaseURLRetrievalFromBundle() {
    //            // Setup: Mocking Bundle.main to return a specified URL
    //            let expectedURL = "https://example.com"
    //            Bundle.mockObject(forInfoDictionaryKey: "BaseURL", object: expectedURL)
    //
    //            // Test
    //            let baseURL = String.theBaseURL
    //
    //            // Verify
    //            XCTAssertEqual(baseURL, expectedURL, "Base URL should be retrieved from Bundle")
    //        }

    // Additional setup to mock Bundle and UserDefaults as needed
    static func mockObject(forInfoDictionaryKey key: String, object: Any?) {
        let original = class_getClassMethod(Bundle.self, #selector(getter: Bundle.main))
        var originalMethod: Method!
        if let original = original {
            originalMethod = method_getImplementation(original)
        }

        let block: @convention(block) (Any?) -> Any? = { _ in return object }
        let imp = imp_implementationWithBlock(block)
        method_setImplementation(originalMethod, imp)
    }

    func testURLRequestCreation() {
        let request = Request<EmptyPayload, EmptyResponse>(
            path: "/test",
            method: .get,
            baseComponents: URLComponents(string: "https://example.com")!,
            initialPath: "/api",
            contentType: "application/json"
        )

        var urlRequest: URLRequest?
        XCTAssertNoThrow(urlRequest = try request.urlRequest(payload: nil))

        XCTAssertNotNil(urlRequest)
        XCTAssertEqual(urlRequest?.url?.absoluteString, "https://example.com/api/test")
        XCTAssertEqual(urlRequest?.httpMethod, "GET")
        XCTAssertEqual(urlRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testURLRequestInitializationFailsWithInvalidURLComponents() {
        var components = URLComponents()
        components.scheme = "https" // A valid scheme
        components.host = "127.0.0.1" // A valid host
        components.port = 80 // A valid port
        // A path that should be valid but will be combined in a way that makes the URL nil
        components.path = "/test" // Normally valid

        // Set the initial path to a malformed string that, when combined with `path`, should result in a nil URL
        let malformedInitialPath = "://badpath"

        let request = Request<EmptyPayload, EmptyResponse>(
            path: components.path,
            method: .get,
            baseComponents: components,
            initialPath: malformedInitialPath, // This should cause the URL to be nil
            contentType: "application/json"
        )

        // The URLRequest should be nil because the initialPath will cause an invalid URL
        XCTAssertThrowsError(
            try request.urlRequest(payload: nil),
            "URLRequest should be nil due to invalid combination of URL components"
        )
    }
}

// Mocks and placeholders used in tests
struct EmptyPayload: Codable {}
struct EmptyResponse: Codable {}
struct SamplePayload: Codable {
    let message: String
}


class RequestTests2: XCTestCase {

    //    // Test the task method with a valid payload
    //    func testTaskWithValidPayload() {
    //        let components = URLComponents(string: "https://example.com/api")!
    //        let request = Request<ValidPayload, EmptyResponse>(
    //            path: "/test",
    //            method: .post,
    //            baseComponents: components,
    //            contentType: "application/json"
    //        )
    //
    //        let encodingExpectation = expectation(description: "Payload should be encoded successfully")
    //
    //        let _ = request.task(
    //            payload: ValidPayload(exampleProperty: "Test"),
    //            passResponse: { _ in
    //                encodingExpectation.fulfill()
    //            },
    //            errorHandler: { error in
    //                XCTFail("Encoding should not fail, but failed with error: \(error)")
    //            }
    //        )
    //
    //        waitForExpectations(timeout: 1)
    //    }

    // Test the task method with an invalid payload that throws during encoding
    func testTaskWithPayloadThatThrowsDuringEncoding() {
        let components = URLComponents(string: "https://example.com/api")!
        let request = Request<InvalidPayload, EmptyResponse>(
            path: "/test",
            method: .post,
            baseComponents: components,
            contentType: "application/json"
        )

        let encodingFailedExpectation = expectation(description: "Encoding should fail")

        let _ = request.task(
            payload: InvalidPayload(unencodableProperty: "Invalid"), // Use the payload that will throw an error
            passResponse: { _ in
                XCTFail("Encoding should fail, but it succeeded")
            },
            errorHandler: { error in
                // Check that the error is of type EncodingError
                if case EncodingError.invalidValue(_, let context) = error {
                    XCTAssertEqual(context.debugDescription, "Invalid value for encoding")
                    encodingFailedExpectation.fulfill()
                } else {
                    XCTFail("Error should be of type EncodingError.invalidValue")
                }
            }
        )
        waitForExpectations(timeout: 1)
    }


}

// Helper Codable structs for tests
struct ValidPayload: Codable {
    let exampleProperty: String
}

struct InvalidPayload: Codable {
    let unencodableProperty: String

    enum CodingKeys: CodingKey {
        case unencodableProperty
    }

    func encode(to encoder: Encoder) throws {
        // Throw an error to simulate failure during encoding.
        throw EncodingError.invalidValue(unencodableProperty, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Invalid value for encoding"))
    }
}
