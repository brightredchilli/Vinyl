//
//  URLSessionUploadTask.swift
//  Vinyl
//
//  Created by Fabio Ritrovato on 01/03/2016.
//  Copyright © 2016 Velhotes. All rights reserved.
//

import Foundation

public final class URLSessionUploadTask: Foundation.URLSessionUploadTask, URLSessionTaskType {
    
    fileprivate let completion: () -> Void
    
    init(uuid: UUID = UUID(), request: URLRequest, completion: @escaping () -> Void) {
        self.completion = completion
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
