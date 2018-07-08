//
//  EncodingDecoding.swift
//  Vinyl
//
//  Created by Rui Peres on 12/02/2016.
//  Copyright © 2016 Velhotes. All rights reserved.
//

import Foundation

// Heavily inspired by Venmo's work on DVR (https://github.com/venmo/DVR).
func encode(body: Data?, headers: HTTPHeaders) -> Any? {

    guard
        let body = body,
        let contentType = headers["Content-Type"]
        else {
            return nil
    }

    switch contentType {

    case _ where contentType.hasPrefix("text/"):
        return String(data: body, encoding: .utf8) as Any?

    case _ where contentType.hasPrefix("application/json"):
        return try? JSONSerialization.jsonObject(with: body, options: .allowFragments)

    default:
        return body.base64EncodedString(options: []) as Any?
    }
}

func decode(body: Any?, headers: HTTPHeaders) -> Data? {

    guard let body = body else { return nil }
    let contentType = headers["Content-Type"] ?? ""

    // handle fragments
    if let string = body as? String {
        return string.data(using: .utf8)
    } else if let integer = body as? Int {
        var int = integer
        return NSData(bytes: &int, length: MemoryLayout.size(ofValue: integer)) as Data
    }

    if let string = body as? String, contentType.hasPrefix("text/") {
        return string.data(using: .utf8)
    }

    if contentType.hasPrefix("application/json") {
        return try? JSONSerialization.data(withJSONObject: body)
    }

    if let string = body as? String {
        return Data(base64Encoded: string, options: [])
    }

    return nil
}
