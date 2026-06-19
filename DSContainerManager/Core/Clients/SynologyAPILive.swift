import Dependencies
import Foundation
import Tagged

// MARK: - Live API Client

extension SynologyAPIClient: DependencyKey {
    static let liveValue: SynologyAPIClient = {
        // Shared URLSession with self-signed cert support
        let sessionDelegate = SynologySessionDelegate()

        return SynologyAPIClient(
            login: { baseURL, username, password, otpCode in
                let session = URLSession(
                    configuration: .ephemeral,
                    delegate: sessionDelegate,
                    delegateQueue: nil
                )
                var params: [String: String] = [
                    "api": "SYNO.API.Auth",
                    "version": "6",
                    "method": "login",
                    "account": username,
                    "passwd": password,
                    "session": "DSContainerManager",
                    "format": "sid",
                    "enable_syno_token": "yes"
                ]
                if let otp = otpCode {
                    params["otp_code"] = otp
                }
                let url = buildURL(baseURL: baseURL, path: "webapi/auth.cgi", params: params)
                let data = try await performRequest(session: session, url: url)
                let response = try decodeResponse(LoginResponseData.self, from: data)
                return response.toSession()
            },

            logout: { baseURL, authSession in
                let session = URLSession(
                    configuration: .ephemeral,
                    delegate: sessionDelegate,
                    delegateQueue: nil
                )
                let params: [String: String] = [
                    "api": "SYNO.API.Auth",
                    "version": "6",
                    "method": "logout",
                    "session": "DSContainerManager",
                    "_sid": authSession.sid.rawValue
                ]
                let url = buildURL(baseURL: baseURL, path: "webapi/auth.cgi", params: params)
                _ = try await performRequest(session: session, url: url)
            },

            listContainers: { baseURL, authSession in
                let session = URLSession(
                    configuration: .ephemeral,
                    delegate: sessionDelegate,
                    delegateQueue: nil
                )
                let params = authenticatedParams(authSession, api: [
                    "api": "SYNO.Docker.Container",
                    "version": "1",
                    "method": "list",
                    "limit": "-1",
                    "offset": "0",
                    "type": "all"
                ])
                let url = buildURL(baseURL: baseURL, path: "webapi/entry.cgi", params: params)
                let data = try await performRequest(session: session, url: url)
                let response = try decodeResponse(ContainerListResponse.self, from: data)
                return response.containers
            },

            getContainerDetail: { baseURL, authSession, containerName in
                let session = URLSession(
                    configuration: .ephemeral,
                    delegate: sessionDelegate,
                    delegateQueue: nil
                )
                let params = authenticatedParams(authSession, api: [
                    "api": "SYNO.Docker.Container",
                    "version": "1",
                    "method": "get",
                    "name": containerName
                ])
                let url = buildURL(baseURL: baseURL, path: "webapi/entry.cgi", params: params)
                let data = try await performRequest(session: session, url: url)
                return try decodeResponse(ContainerDetail.self, from: data)
            },

            performContainerAction: { baseURL, authSession, containerName, action in
                let session = URLSession(
                    configuration: .ephemeral,
                    delegate: sessionDelegate,
                    delegateQueue: nil
                )
                let apiMethod: String
                switch action {
                case .start: apiMethod = "start"
                case .stop: apiMethod = "stop"
                case .restart: apiMethod = "restart"
                case .pause: apiMethod = "pause"
                case .unpause: apiMethod = "unpause"
                case .kill: apiMethod = "signal"
                }
                var apiParams: [String: String] = [
                    "api": "SYNO.Docker.Container",
                    "version": "1",
                    "method": apiMethod,
                    "name": containerName
                ]
                if action == .kill {
                    apiParams["signal"] = "SIGKILL"
                }
                let params = authenticatedParams(authSession, api: apiParams)
                let url = buildURL(baseURL: baseURL, path: "webapi/entry.cgi", params: params)
                _ = try await performRequest(session: session, url: url)
            },

            getContainerLogs: { baseURL, authSession, containerName, offset, limit in
                let session = URLSession(
                    configuration: .ephemeral,
                    delegate: sessionDelegate,
                    delegateQueue: nil
                )
                let requestedOffset = max(offset, 0)
                let requestedLimit = max(limit, 1)
                let params = authenticatedParams(authSession, api: [
                    "api": "SYNO.Docker.Container.Log",
                    "version": "1",
                    "method": "get",
                    "name": containerName,
                    "from": "",
                    "to": "",
                    "level": "",
                    "keyword": "",
                    "sort_dir": "DESC",
                    "offset": String(requestedOffset),
                    "limit": String(requestedLimit)
                ])
                let url = buildURL(baseURL: baseURL, path: "webapi/entry.cgi", params: params)
                let data = try await performRequest(session: session, url: url)
                #if DEBUG
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("[SynologyAPI] Response for ContainerLog name=\(containerName) (\(data.count) bytes): \(jsonString.prefix(2000))")
                }
                #endif
                return try decodeLogResponse(from: data, containerName: containerName)
            },

            getContainerResources: { baseURL, authSession in
                let session = URLSession(
                    configuration: .ephemeral,
                    delegate: sessionDelegate,
                    delegateQueue: nil
                )
                let params = authenticatedParams(authSession, api: [
                    "api": "SYNO.Docker.Container.Resource",
                    "version": "1",
                    "method": "get"
                ])
                let url = buildURL(baseURL: baseURL, path: "webapi/entry.cgi", params: params)
                let data = try await performRequest(session: session, url: url)
                return try decodeResourceResponse(from: data)
            },

            listProjects: { baseURL, authSession in
                let session = URLSession(
                    configuration: .ephemeral,
                    delegate: sessionDelegate,
                    delegateQueue: nil
                )
                let params = authenticatedParams(authSession, api: [
                    "api": "SYNO.Docker.Project",
                    "version": "1",
                    "method": "list",
                    "limit": "-1",
                    "offset": "0"
                ])
                let url = buildURL(baseURL: baseURL, path: "webapi/entry.cgi", params: params)
                let data = try await performRequest(session: session, url: url)
                let response = try decodeResponse(ProjectListResponse.self, from: data)
                return response.projects
            },

            getProjectDetail: { baseURL, authSession, projectId in
                let session = URLSession(
                    configuration: .ephemeral,
                    delegate: sessionDelegate,
                    delegateQueue: nil
                )
                let params = authenticatedParams(authSession, api: [
                    "api": "SYNO.Docker.Project",
                    "version": "1",
                    "method": "get",
                    "id": projectId
                ])
                let url = buildURL(baseURL: baseURL, path: "webapi/entry.cgi", params: params)
                let data = try await performRequest(session: session, url: url)
                return try decodeResponse(ComposeProject.self, from: data)
            },

            performProjectAction: { baseURL, authSession, projectId, action in
                let session = URLSession(
                    configuration: .ephemeral,
                    delegate: sessionDelegate,
                    delegateQueue: nil
                )
                let apiMethod: String
                switch action {
                case .start: apiMethod = "start"
                case .stop: apiMethod = "stop"
                case .restart: apiMethod = "restart"
                }
                let params = authenticatedParams(authSession, api: [
                    "api": "SYNO.Docker.Project",
                    "version": "1",
                    "method": apiMethod,
                    "id": projectId
                ])
                let url = buildURL(baseURL: baseURL, path: "webapi/entry.cgi", params: params)
                _ = try await performRequest(session: session, url: url)
            },

            getSystemUtilization: { baseURL, authSession in
                let session = URLSession(
                    configuration: .ephemeral,
                    delegate: sessionDelegate,
                    delegateQueue: nil
                )
                let params = authenticatedParams(authSession, api: [
                    "api": "SYNO.Core.System.Utilization",
                    "version": "1",
                    "method": "get"
                ])
                let url = buildURL(baseURL: baseURL, path: "webapi/entry.cgi", params: params)
                let data = try await performRequest(session: session, url: url)
                return try decodeResponse(SystemUtilization.self, from: data)
            },

            getStorageInfo: { baseURL, authSession in
                let session = URLSession(
                    configuration: .ephemeral,
                    delegate: sessionDelegate,
                    delegateQueue: nil
                )
                let params = authenticatedParams(authSession, api: [
                    "api": "SYNO.Core.Storage.Volume",
                    "version": "1",
                    "method": "list",
                    "limit": "-1",
                    "offset": "0",
                    "location": "internal"
                ])
                let url = buildURL(baseURL: baseURL, path: "webapi/entry.cgi", params: params)
                let data = try await performRequest(session: session, url: url)
                return try decodeResponse(StorageInfo.self, from: data)
            }
        )
    }()
}

// MARK: - URL Building

private func buildURL(baseURL: URL, path: String, params: [String: String]) -> URL {
    var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
    components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
    guard let url = components.url else {
        fatalError("Failed to build URL from \(baseURL) / \(path)")
    }
    return url
}

private func authenticatedParams(_ session: AuthSession, api: [String: String]) -> [String: String] {
    var params = api
    params["_sid"] = session.sid.rawValue
    if let token = session.synotoken {
        params["SynoToken"] = token
    }
    return params
}

// MARK: - Network Request

private func performRequest(session: URLSession, url: URL) async throws -> Data {
    var request = URLRequest(url: url)
    request.timeoutInterval = 30
    return try await performRequest(session: session, request: request)
}

private func performRequest(session: URLSession, request: URLRequest) async throws -> Data {
    let (data, response): (Data, URLResponse)
    do {
        (data, response) = try await session.data(for: request)
    } catch let urlError as URLError {
        throw SynologyAPIError.networkError(urlError.localizedDescription)
    } catch {
        throw SynologyAPIError.networkError(error.localizedDescription)
    }

    guard let httpResponse = response as? HTTPURLResponse else {
        throw SynologyAPIError.networkError("Invalid response")
    }

    guard (200...299).contains(httpResponse.statusCode) else {
        throw SynologyAPIError.networkError("HTTP \(httpResponse.statusCode)")
    }

    return data
}

// MARK: - Response Decoding

private func decodeResponse<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970

    // Debug: print raw JSON for troubleshooting
    #if DEBUG
    if let jsonString = String(data: data, encoding: .utf8) {
        let preview = jsonString.prefix(2000)
        print("[SynologyAPI] Response for \(T.self) (\(data.count) bytes): \(preview)")
    }
    #endif

    let synologyResponse: SynologyResponse<T>
    do {
        synologyResponse = try decoder.decode(SynologyResponse<T>.self, from: data)
    } catch {
        #if DEBUG
        print("[SynologyAPI] Decode error for \(T.self): \(error)")
        #endif
        throw SynologyAPIError.decodingError(error.localizedDescription)
    }

    guard synologyResponse.success else {
        if let errorPayload = synologyResponse.error {
            throw SynologyAPIError.fromErrorCode(errorPayload.code)
        }
        throw SynologyAPIError.unknownError("Request failed without error details")
    }

    guard let responseData = synologyResponse.data else {
        throw SynologyAPIError.decodingError("Response succeeded but contained no data")
    }

    return responseData
}

// MARK: - Log Response Decoding

/// DSM Container Manager returns logs as `{ logs: [{ created, text, stream }], total }`.
/// Older Docker API shapes may still return flat strings, so keep that fallback.
private func decodeLogResponse(from data: Data, containerName: String) throws -> [ContainerLog] {
    struct LogResponseData: Decodable {
        let entries: [LogEntry]
        let offset: Int?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            entries = (try? container.decode([LogEntry].self, forKey: .logs))
                ?? (try? container.decode([LogEntry].self, forKey: .log))
                ?? []
            offset = try? container.decode(Int.self, forKey: .offset)
        }

        enum CodingKeys: String, CodingKey {
            case logs
            case log
            case offset
        }
    }

    struct LogEntry: Decodable {
        let timestamp: Date
        let stream: ContainerLog.LogStream
        let text: String

        init(from decoder: Decoder) throws {
            if let singleValue = try? decoder.singleValueContainer(),
               let line = try? singleValue.decode(String.self) {
                let parsed = parseLogLine(line)
                timestamp = parsed.0
                stream = parsed.1
                text = parsed.2
                return
            }

            let container = try decoder.container(keyedBy: CodingKeys.self)
            timestamp = Self.decodeTimestamp(
                from: container,
                keys: [.timestamp, .time, .date, .created, .createdAt]
            ) ?? .now

            let rawStream = (try? container.decode(String.self, forKey: .stream))
                ?? (try? container.decode(String.self, forKey: .source))
                ?? "unknown"
            stream = ContainerLog.LogStream(rawValue: rawStream.lowercased()) ?? .unknown

            text = (try? container.decode(String.self, forKey: .text))
                ?? (try? container.decode(String.self, forKey: .message))
                ?? (try? container.decode(String.self, forKey: .msg))
                ?? (try? container.decode(String.self, forKey: .output))
                ?? ""
        }

        private static func decodeTimestamp(
            from container: KeyedDecodingContainer<CodingKeys>,
            keys: [CodingKeys]
        ) -> Date? {
            for key in keys {
                if let rawString = try? container.decode(String.self, forKey: key) {
                    if let numericValue = Double(rawString) {
                        return date(fromNumericTimestamp: numericValue)
                    }
                    if let date = parseLogDate(rawString) {
                        return date
                    }
                }

                if let rawDouble = try? container.decode(Double.self, forKey: key) {
                    return date(fromNumericTimestamp: rawDouble)
                }

                if let rawInt = try? container.decode(Int64.self, forKey: key) {
                    return date(fromNumericTimestamp: Double(rawInt))
                }
            }

            return nil
        }

        enum CodingKeys: String, CodingKey {
            case timestamp
            case time
            case date
            case created
            case createdAt = "created_at"
            case stream
            case source
            case text
            case message
            case msg
            case output = "Output"
        }
    }

    let decoder = JSONDecoder()
    let synologyResponse: SynologyResponse<LogResponseData>
    do {
        synologyResponse = try decoder.decode(SynologyResponse<LogResponseData>.self, from: data)
    } catch {
        throw SynologyAPIError.decodingError(error.localizedDescription)
    }

    guard synologyResponse.success else {
        if let errorPayload = synologyResponse.error {
            throw SynologyAPIError.fromErrorCode(errorPayload.code)
        }
        throw SynologyAPIError.unknownError("Log request failed")
    }

    guard let logData = synologyResponse.data else {
        return []
    }

    return logData.entries.enumerated().compactMap { index, entry in
        guard !entry.text.isEmpty else { return nil }
        return ContainerLog(
            id: UUID(),
            timestamp: entry.timestamp,
            stream: entry.stream,
            text: entry.text,
            offset: (logData.offset ?? 0) + index
        )
    }
}

private func parseLogLine(_ line: String) -> (Date, ContainerLog.LogStream, String) {
    // Try to parse Docker log format: "timestamp stream message"
    let components = line.split(separator: " ", maxSplits: 2)

    if components.count >= 3 {
        let timestampStr = String(components[0])
        let streamStr = String(components[1]).lowercased()
        let message = String(components[2])

        let timestamp = parseLogDate(timestampStr) ?? .now
        let stream: ContainerLog.LogStream = {
            switch streamStr {
            case "stdout": return .stdout
            case "stderr": return .stderr
            default: return .unknown
            }
        }()

        return (timestamp, stream, message)
    }

    // Fallback: treat entire line as stdout message
    return (.now, .unknown, line)
}

private func parseLogDate(_ rawValue: String) -> Date? {
    let formatterWithFractions = ISO8601DateFormatter()
    formatterWithFractions.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatterWithFractions.date(from: rawValue) {
        return date
    }

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    if let date = formatter.date(from: rawValue) {
        return date
    }

    if let timestamp = Double(rawValue) {
        return date(fromNumericTimestamp: timestamp)
    }

    return nil
}

private func date(fromNumericTimestamp rawValue: Double) -> Date {
    let seconds = rawValue > 10_000_000_000 ? rawValue / 1_000 : rawValue
    return Date(timeIntervalSince1970: seconds)
}

// MARK: - Resource Response Decoding

private func decodeResourceResponse(from data: Data) throws -> [ContainerResources] {
    struct ResourceResponseData: Decodable {
        let resources: [RawContainerResource]?

        struct RawContainerResource: Decodable {
            let container: String?
            let cpu: Double?
            let memoryUsage: Int64?
            let memoryLimit: Int64?
            let networkRx: Int64?
            let networkTx: Int64?
            let blockRead: Int64?
            let blockWrite: Int64?

            enum CodingKeys: String, CodingKey {
                case container
                case cpu
                case memoryUsage = "memory_usage"
                case memoryLimit = "memory_limit"
                case networkRx = "network_rx"
                case networkTx = "network_tx"
                case blockRead = "block_read"
                case blockWrite = "block_write"
            }
        }
    }

    let decoder = JSONDecoder()
    let synologyResponse: SynologyResponse<ResourceResponseData>
    do {
        synologyResponse = try decoder.decode(SynologyResponse<ResourceResponseData>.self, from: data)
    } catch {
        throw SynologyAPIError.decodingError(error.localizedDescription)
    }

    guard synologyResponse.success else {
        if let errorPayload = synologyResponse.error {
            throw SynologyAPIError.fromErrorCode(errorPayload.code)
        }
        throw SynologyAPIError.unknownError("Resource request failed")
    }

    guard let resourceData = synologyResponse.data, let resources = resourceData.resources else {
        return []
    }

    return resources.compactMap { raw in
        guard let name = raw.container else { return nil }
        return ContainerResources(
            containerName: name,
            cpuPercent: raw.cpu ?? 0,
            memoryUsage: raw.memoryUsage ?? 0,
            memoryLimit: raw.memoryLimit ?? 0,
            networkRx: raw.networkRx ?? 0,
            networkTx: raw.networkTx ?? 0,
            blockRead: raw.blockRead ?? 0,
            blockWrite: raw.blockWrite ?? 0
        )
    }
}

// MARK: - Self-Signed Certificate Support

final class SynologySessionDelegate: NSObject, URLSessionDelegate, Sendable {
    nonisolated func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        // Trust self-signed certificates for Synology NAS devices
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            return (.performDefaultHandling, nil)
        }

        let credential = URLCredential(trust: serverTrust)
        return (.useCredential, credential)
    }
}
