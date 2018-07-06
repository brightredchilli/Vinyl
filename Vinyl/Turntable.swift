//
//  Turntable.swift
//  Vinyl
//
//  Created by Rui Peres on 12/02/2016.
//  Copyright © 2016 Velhotes. All rights reserved.
//

import Foundation

enum TurntableError: Error {

    case trackNotFound
    case noRecordingPath
    case nothingToRecord
}

public typealias Plastic = [[String: Any]]
typealias RequestCompletionHandler =  (Data?, URLResponse?, Error?) -> Void

public final class Turntable: URLSession {

    var errorHandler: ErrorHandler = DefaultErrorHandler()
    fileprivate let turntableConfiguration: TurntableConfiguration
    fileprivate var player: Player?
    var recorder: Recorder?
    fileprivate var recordingSession: URLSession?
    fileprivate let operationQueue: OperationQueue

    public init(configuration: TurntableConfiguration, delegateQueue: OperationQueue? = nil, urlSession: URLSession? = nil) {

        turntableConfiguration = configuration
        if let delegateQueue = delegateQueue {
            operationQueue = delegateQueue
        } else {
            operationQueue = OperationQueue()
            operationQueue.maxConcurrentOperationCount = 1
        }

        recordingSession = urlSession
        if configuration.recodingEnabled {
            recorder = Recorder(wax: Wax(tracks: []), recordingPath: configuration.recordingPath)
            recordingSession = recordingSession ?? URLSession.shared
        }

        super.init()
    }

    public convenience init(vinyl: Vinyl,
                            turntableConfiguration: TurntableConfiguration = TurntableConfiguration(),
                            delegateQueue: OperationQueue? = nil,
                            urlSession: URLSession? = nil) {
        self.init(configuration: turntableConfiguration, delegateQueue: delegateQueue, urlSession: urlSession)
        player = Turntable.createPlayer(with: vinyl, configuration: turntableConfiguration)
    }

    public convenience init(cassetteName: String,
                            bundle: Bundle = Bundle.testingBundle(),
                            turntableConfiguration: TurntableConfiguration = TurntableConfiguration(),
                            delegateQueue: OperationQueue? = nil,
                            urlSession: URLSession? = nil) {
        let vinyl = Vinyl(plastic: Turntable.createPlastic(cassette: cassetteName, bundle: bundle))
        self.init(vinyl: vinyl, turntableConfiguration: turntableConfiguration, delegateQueue: delegateQueue, urlSession: urlSession)
    }

    public convenience init(vinylName: String,
                            bundle: Bundle = Bundle.testingBundle(),
                            turntableConfiguration: TurntableConfiguration = TurntableConfiguration(),
                            delegateQueue: OperationQueue? = nil,
                            urlSession: URLSession? = nil) {
        let plastic = Turntable.createPlastic(vinyl: vinylName, bundle: bundle, recordingMode: turntableConfiguration.recordingMode)
        let vinyl = Vinyl(plastic: plastic ?? [])
        self.init(vinyl: vinyl, turntableConfiguration: turntableConfiguration, delegateQueue: delegateQueue, urlSession: urlSession)

        recordingSession = urlSession
        switch turntableConfiguration.recordingMode {
        case .missingVinyl where plastic == nil, .missingTracks:
            recorder = Recorder(wax: Wax(vinyl: vinyl), recordingPath: recordingPath(fromConfiguration: turntableConfiguration, vinylName: vinylName, bundle: bundle))
        default:
            recorder = nil

        }
    }

    deinit {
        stopRecording()
    }

    public func stopRecording() {
        guard let recorder = recorder else {
            return
        }

        do {
            try recorder.persist()
        }
        catch TurntableError.nothingToRecord {
            print("Nothing to record.")
        }
        catch TurntableError.noRecordingPath {
            fatalError("💣 no path was configured for saving the recording.")
        }
        catch let error as NSError {
            fatalError("💣 we couldn't save the recording: \(error.localizedDescription)")
        }
    }

    // MARK: - Private methods

    fileprivate func playVinyl(request: URLRequest, fromData bodyData: Data? = nil, completionHandler: @escaping RequestCompletionHandler) throws -> URLSessionTask {
        guard let player = player else {
            fatalError("Did you forget to load the Vinyl? 🎶")
        }
       let completion = try player.playTrack(for: transform(request: request, bodyData: bodyData))

        let vinylTask = VinylURLSessionDataTask(request: request) {
            self.operationQueue.addOperation {
                completionHandler(completion.data, completion.response, completion.error)
            }
        }
        return vinylTask as Foundation.URLSessionTask
    }

    fileprivate func recordingHandler(request: URLRequest, fromData bodyData: Data? = nil, completionHandler: @escaping ((Data?, URLResponse?, Error?) -> Void)) -> ((Data?, URLResponse?, Error?) -> Void) {
        guard let recorder = recorder else {
            fatalError("No recording started.")
        }
        return {
            data, response, error in

            recorder.saveTrack(with: self.transform(request: request, bodyData: bodyData), urlResponse: response as? HTTPURLResponse, body: data, error: error)

            let anyclosure: Any = completionHandler
            let closureType = type(of: anyclosure)
            if closureType == ((Data?, URLResponse?, Error?) -> Void).self {
                self.operationQueue.addOperation {
                    completionHandler(data, response, error)
                }

            }
//            ((Data?, URLResponse?, Error?) -> Void).Type
        }
    }

    fileprivate func transform(request: URLRequest, bodyData: Data? = nil) -> URLRequest {
        guard let bodyData = bodyData else {
            return request
        }

        guard let mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            fatalError("💥 Houston, we have a problem 🚀")
        }

        mutableRequest.httpBody = bodyData

        return mutableRequest as URLRequest
    }

    fileprivate func recordingPath(fromConfiguration configuration: TurntableConfiguration, vinylName: String, bundle: Bundle) -> String? {
        if let recordingPath = configuration.recordingPath {
            return recordingPath
        }

        return bundle.resourceURL?.appendingPathComponent(vinylName).appendingPathExtension("json").path
    }

    public override var delegate: URLSessionDelegate? {
        return recordingSession?.delegate
    }
}


// MARK: - NSURLSession methods

extension Turntable {

//    public override func dataTask(with url: URL) -> Foundation.URLSessionDataTask {
//        return dataTask(with: URLRequest(url: url))
//    }

    public override func dataTask(with request: URLRequest) -> Foundation.URLSessionDataTask {

        guard let player = player,
            let recordingSession = recordingSession else { fatalError("player should be initialized") }

        do {

            let completion = try player.playTrack(for: transform(request: request, bodyData: nil))
            let task = VinylURLSessionDataTask(request: request, response: completion.response, completion: {})

            task.completion = {
                if let delegate = recordingSession.delegate as? URLSessionDataDelegate,
                    let data = completion.data {
                    self.operationQueue.addOperation {
                        delegate.urlSession?(recordingSession,
                                            dataTask: task,
                                            didReceive: data)
                    }
                }
                if let delegate = recordingSession.delegate as? URLSessionTaskDelegate {
                    self.operationQueue.addOperation {
                        delegate.urlSession?(recordingSession,
                                            task: task,
                                            didCompleteWithError: completion.error)
                    }
                }
            }
            return task

        }
        catch TurntableError.trackNotFound {
            return recordingSession.dataTask(with: request)
//            if let session = recordingSession {
//
//            }
//            else {
//                errorHandler.handleTrackNotFound(request, playTracksUniquely: turntableConfiguration.playTracksUniquely)
//            }
        }
        catch {
            errorHandler.handleUnknownError()
        }


        // create an object reference holding the identifier
        // create the datatask first

        // let mydatatask = MyDataTask(identifier: hash)
//        mydatatask.completion = {
//            recordingSession?.delegate.urlsessiondidfinish(recordingSession, mydatatask, nil)
//        }

      // let completion = try player.playVinyl()
      //chr
      // on the queue  recordingSession?.delegate.urlSession(recordingSession, dataTask: mydataTask, didReceive:)
      // on the queue  recordingSession?.delegate.urlSession(recordingSession, dataTask: mydataTask, didCompleteWithError:)

        // try to play the record.


        return dataTask(with: request, completionHandler: {_, _, _ in })
    }

    public override func dataTask(with url: URL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> Foundation.URLSessionDataTask {
        let request = URLRequest(url: url)
        return dataTask(with: request, completionHandler: completionHandler)
    }

    public override func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> Foundation.URLSessionDataTask {

        do {
            if let task = try playVinyl(request: request, completionHandler: completionHandler) as? URLSessionDataTask {
                return task
            } else {
                fatalError("Should not happen")
            }
        }
        catch TurntableError.trackNotFound {
            if let session = recordingSession {
                return session.dataTask(with: request, completionHandler: recordingHandler(request: request, completionHandler: completionHandler))
            }
            else {
                errorHandler.handleTrackNotFound(request, playTracksUniquely: turntableConfiguration.playTracksUniquely)
            }
        }
        catch {
            errorHandler.handleUnknownError()
        }

        return VinylURLSessionDataTask(request: request, completion: {})
    }

    public override func uploadTask(with request: URLRequest, from bodyData: Data?, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> Foundation.URLSessionUploadTask {

        do {
            if let task = try playVinyl(request: request, fromData: bodyData, completionHandler: completionHandler) as? URLSessionUploadTask {
                return task
            } else {
                fatalError("Should not happen")
            }
        }
        catch TurntableError.trackNotFound {
            if let session = recordingSession {
                return session.uploadTask(with: request, from: bodyData, completionHandler: recordingHandler(request: request, fromData: bodyData, completionHandler: completionHandler))
            }
            else {
                errorHandler.handleTrackNotFound(request, playTracksUniquely: turntableConfiguration.playTracksUniquely)
            }
        }
        catch {
            errorHandler.handleUnknownError()
        }

        return URLSessionUploadTask(request: request, completion: {})
    }

    public override func invalidateAndCancel() {
        // We won't do anything for
    }
}

// MARK: - Loading Methods

extension Turntable {

    public func load(vinyl vinylName: String,  bundle: Bundle = Bundle.testingBundle()) {
        let plastic = Turntable.createPlastic(vinyl: vinylName, bundle: bundle, recordingMode: turntableConfiguration.recordingMode)
        let vinyl = Vinyl(plastic: plastic ?? [])
        player = Turntable.createPlayer(with: vinyl, configuration: turntableConfiguration)

        switch turntableConfiguration.recordingMode {
        case .missingVinyl where plastic == nil, .missingTracks:
            recorder = Recorder(wax: Wax(vinyl: vinyl), recordingPath: recordingPath(fromConfiguration: turntableConfiguration, vinylName: vinylName, bundle: bundle))
        default:
            recorder = nil
            recordingSession = nil
        }
    }

    public func load(cassette cassetteName: String,  bundle: Bundle = Bundle.testingBundle()) {

        let vinyl = Vinyl(plastic: Turntable.createPlastic(cassette: cassetteName, bundle: bundle))
        player = Turntable.createPlayer(with: vinyl, configuration: turntableConfiguration)
    }

    public func load(vinyl: Vinyl) {
        player = Turntable.createPlayer(with: vinyl, configuration: turntableConfiguration)
    }
}

// MARK: - Bootstrap methods

extension Turntable {

    fileprivate static func createPlayer(with vinyl: Vinyl, configuration: TurntableConfiguration) -> Player {

        let trackMatchers = configuration.trackMatchers(for: vinyl)
        return Player(vinyl: vinyl, trackMatchers: trackMatchers)
    }

    fileprivate static func createPlastic(cassette cassetteName: String, bundle: Bundle) -> Plastic {

        guard let cassette: [String: AnyObject] = loadJSON(from: bundle, fileName: cassetteName) else {
            fatalError("💣 Cassette file \"\(cassetteName)\" not found 😩")
        }

        guard let plastic = cassette["interactions"] as? Plastic else {
            fatalError("💣 We couldn't find the \"interactions\" key in your cassette 😩")
        }

        return plastic
    }

    static func createPlastic(vinyl vinylName: String, bundle: Bundle, recordingMode: RecordingMode) -> Plastic? {
        if let plastic: Plastic = loadJSON(from: bundle, fileName: vinylName) {
            return plastic
        }

        switch recordingMode {
        case .none, .missingTracks:
            fatalError("💣 Vinyl file \"\(vinylName)\" not found 😩")
        case .missingVinyl:
            return nil
        }
    }

    static func createPlastic(absolutePath: String) -> Plastic? {
        if let plastic: Plastic = loadJSON(fromPath: absolutePath) {
            return plastic
        } else {
            return nil
        }
    }
}
