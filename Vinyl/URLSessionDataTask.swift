//
//  URLSessionDataTask.swift
//  Vinyl
//
//  Created by Rui Peres on 16/02/2016.
//  Copyright © 2016 Velhotes. All rights reserved.
//

import Foundation

public final class VinylURLSessionDataTask: Foundation.URLSessionDataTask, URLSessionTaskType {

    var completion: () -> Void
    private let uuid: UUID
    let _originalRequest: URLRequest?
    let _response: URLResponse?
    
    public override var taskIdentifier: Int {
      return uuid.hashValue
    }

    public override var originalRequest: URLRequest? {
        return _originalRequest
    }

    public override var response: URLResponse? {
        return _response
    }

    convenience init(uuid: UUID = UUID(), request: URLRequest, completion: @escaping () -> Void) {
        self.init(uuid: uuid, request: request, response: nil, completion: {})
    }

    init(uuid: UUID = UUID(), request: URLRequest, response: URLResponse?, completion: @escaping () -> Void) {
        self.completion = completion
        self.uuid = uuid
        _originalRequest = request
        _response = response
    }

   public override func resume() {
        completion()
    }

   public override func suspend() {
        // We won't do anything here
    }

   public override func cancel() {
        // We won't do anything here
    }
}
