//
//  Recorder.swift
//  Vinyl
//
//  Created by Michael Brown on 07/08/2016.
//  Copyright © 2016 Velhotes. All rights reserved.
//

import Foundation

public final class Recorder {
    var wax: Wax
    let recordingPath: String?
    var somethingRecorded = false

    init(wax: Wax, recordingPath: String?) {
        self.wax = wax
        self.recordingPath = recordingPath
    }

    func saveTrack(with request: Request, response: Response) {
        wax.add(track: Track(request: request, response: response))
        somethingRecorded = true
    }

    public func saveTrack(with request: Request, urlResponse: HTTPURLResponse?, body: Data? = nil, error: Error? = nil) {
        let response = Response(urlResponse: urlResponse, body: body, error: error)
        saveTrack(with: request, response: response)
    }

    public func persist() throws {
        guard let recordingPath = recordingPath, somethingRecorded else {
            if somethingRecorded {
                throw TurntableError.noRecordingPath
            } else {
                throw TurntableError.nothingToRecord
            }
        }

        let fileManager = FileManager.default
        guard fileManager.createFile(atPath: recordingPath, contents: nil, attributes: nil) == true,
            let file = FileHandle(forWritingAtPath: recordingPath) else {
                return
        }

        let jsonWax = wax.tracks.map {
            $0.encodedTrack()
        }

        let data = try JSONSerialization.data(withJSONObject: jsonWax, options: .prettyPrinted)
        file.write(data)
        file.synchronizeFile()

        print("Vinyl recorded to: \(recordingPath)")
        somethingRecorded = false
    }

}
