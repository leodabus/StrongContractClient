//
//  File.swift
//  
//
//  Created by Scott Lydon on 4/29/24.
//

import Foundation

extension String {

    /// Attempts to find the base url by checking
    public static var theBaseURL: String {
        if let cachedURL = _cachedBaseURL {
            return cachedURL
        }

        guard let url = defaultPath ??
                typicalKeys.compactMap(usualCandidates).first else {
            #if canImport(os)
            let errorString =
                """
                No base URL is set. Please assign it to global
                `StrongContractClient.defaultPath` before using `Request`.

                We recommend assigning it in `AppDelegate`, `App`, or store it
                in `Bundle.main.object`, `UserDefaults`, `ProcessInfo.processInfo.environment`.
                """
            errorString.logInfo()
            assertionFailure(errorString)
            #endif
            return ""
        }
        _cachedBaseURL = url
        return url
    }

    /// Cache the base URL to avoid repeated lookups.
    internal static var _cachedBaseURL: String?

    /// Typical keys developers might use to store their base url.
    public static var typicalKeys: [String] = [
        "BaseURL",
        "BASE_URL",
        "APIBaseURL",
        "ServerURL",
        "EndpointURL",
        "HostURL",
        "WebServiceURL",
        "ServiceEndpoint",
        "RootURL",
        "APIHost"
    ]

    ///  A package doesn't know the base url of the user's project, so this is kind of a searching method for the user's convenience.
    /// Tries each key to find a stored base URL.
    /// - Parameter key: the key used to identify the base URL.
    /// - Returns: a base URL if one is found, nil if not.
    static func usualCandidates(for key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ??
        UserDefaults.standard.string(forKey: key) ??
        loadBaseURLFromJSON(key: key) ??
        ProcessInfo.processInfo.environment[key]
    }

    /// Attempts to load a base url from JSON
    /// - Parameter key: The key used to find the url.
    /// - Returns: returns the url if found, nil if not.
    static func loadBaseURLFromJSON(key: String) -> String? {
        guard let url = Bundle.main.url(forResource: "config", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
              let dictionary = jsonObject as? [String: Any],
              let baseURL = dictionary[key] as? String else {
            return nil
        }
        return baseURL
    }
}
