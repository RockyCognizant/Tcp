//
//  HTTP11.swift
//  
//
//  Created by Rocky Wei on 2/20/23.
//

import Foundation

open class HttpResponse {
    internal let version = "HTTP/1.0"
    public var headers: [String: String] = [:]
    internal let body: Data
    internal var code = 200
    public init(raw: Data) {
        body = raw
    }
    public convenience init(content: String? = nil) {
        let data = content?.data(using: .utf8) ?? Data()
        self.init(raw: data)
    }
    public convenience init<T: Encodable>(encodable: T) throws {
        let data = try JSONEncoder().encode(encodable)
        self.init(raw: data)
    }
    public func encode() throws -> Data {
        headers["date"] = "\(Date())"
        headers["content-length"] = "\(body.count)"
        let content = (["\(version) \(code)"] + headers.map { "\($0.key): \($0.value)" })
            .joined(separator: "\r\n") + "\r\n\r\n"
        guard let payload = content.data(using: .utf8) else {
            throw NSError(domain: "invalid payload encoding", code: 0)
        }
        return payload + body
    }
}

public struct HttpRequest {
    public enum Method: String {
        case GET
        case POST
        case HEAD
    }
    public let uri: URI
    public let method: Method
    public let version: String
    public let headers: [String: String]
    public let body: Data
    public init?(request: Data) throws {
        let headData: Data
        if let separator = request.firstRange(of: "\r\n\r\n".data(using: .utf8) ?? Data()) {
            headData = request[request.startIndex..<separator.lowerBound]
            body = request[separator.upperBound..<request.endIndex]
        } else {
            headData = request
            body = Data()
        }
        let head = String(data: headData, encoding: .utf8) ?? ""
        var lines = head.split(separator: "\r\n").map { String($0).trimmed }
        let uriPattern = try NSRegularExpression(pattern: "^(GET|POST|HEAD) (.*) HTTP/([0-9.]+)$", options: .caseInsensitive)
        let headerPattern = try NSRegularExpression(pattern: "^([a-zA-Z\\-]+):\\s(.*)$")
        guard !lines.isEmpty else {
            throw NSError(domain: "Bad Request", code: 400)
        }
        let top = lines.removeFirst()
        guard let uriMatch = uriPattern.firstMatch(in: top, range: top.range) else {
            throw NSError(domain: "Bad Request", code: 400)
        }
        let headString = head as NSString
        let methodRange = uriMatch.range(at: 1)
        method = Method(rawValue: headString.substring(with: methodRange).uppercased()) ?? .GET
        let uriRange = uriMatch.range(at: 2)
        let uriString = headString.substring(with: uriRange)
        let versionRange = uriMatch.range(at: 3)
        version = headString.substring(with: versionRange)
        uri = URI(uri: uriString)
        let keyValues = lines.compactMap { line -> (String, String)? in
            guard let expressionMatch = headerPattern.firstMatch(in: line, range: line.range) else {
                return nil
            }
            let keyRange = expressionMatch.range(at: 1)
            let valueRange = expressionMatch.range(at: 2)
            let expression = line as NSString
            let key = expression.substring(with: keyRange)
            let value = expression.substring(with: valueRange)
            return (key, value)
        }
        headers = Dictionary(uniqueKeysWithValues: keyValues)
        if let textContentLength = headers["Content-Length"], let contentLength = Int(textContentLength) {
            let size = body.count
            guard size >= contentLength else {
                return nil
            }
        }
    }
    public var content: String? {
        return String(data: body, encoding: .utf8)
    }
}

public struct URI {
    public let raw: String
    public let path: [String]
    public let parameters: [String: String]
    public init(uri: String) {
        raw = uri
        let resources = uri.split(separator: "?").map { String($0) }
        let api: String
        if let _api = resources.first {
            api = _api
            if resources.count > 1, let _params = resources.last {
                let keyValues = _params.split(separator: "&").compactMap { expression -> (String, String)? in
                    guard let equal = expression.firstIndex(of: "=") else {
                        return nil
                    }
                    let key = expression[expression.startIndex..<equal]
                    let value = expression[expression.index(equal, offsetBy: 1)..<expression.endIndex]
                    return (String(key), String(value))
                }
                parameters = Dictionary(uniqueKeysWithValues: keyValues)
            } else {
                parameters = [:]
            }
        } else {
            api = uri
            parameters = [:]
        }
        path = api.split(separator: "/").map { String($0) }
    }
}
public extension String {
    var trimmed: String {
        let blanks = CharacterSet(charactersIn: " \t\r\n")
        return trimmingCharacters(in: blanks)
    }
    var range: NSRange {
        return NSRange(location: 0, length: count)
    }
}
