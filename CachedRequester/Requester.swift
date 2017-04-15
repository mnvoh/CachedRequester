//
//  Requester.swift
//  CachedRequester
//
//  Created by Milad on 4/14/17.
//  Copyright © 2017 Milad Nozary. All rights reserved.
//

import Foundation

public enum RequestStatus {
  case pending, started, finished, canceled
}

/// When making a request, an instance of this class will be returned so that the request
/// can be paused, canceled or resumed.
open class RequestHandle {
  
  // MARK: Properties
  
  /// If the same request is made several times we need a unique identifier
  /// to be able to cancel a specific one.
  open let sessionId: String
  
  /// The handle to the sesison of the data task
  open let session: URLSessionTask
  
  /// `completionHandler` will be called when the request is complete
  open let completionHandler: Requester.CompletionHandler
  
  /// `progressHandler` will be called perdiodically to report the progress of the request
  open let progressHandler: Requester.ProgressHandler
  
  /// The status of the request, pending (not started), started, finished or canceled
  open var status: RequestStatus
  
  /// The total size of the response. Since it's not determined at first, we initialize it to 0
  open var totalSize: UInt
  
  /// The downloaded data
  open var data: Data
  
  // MARK: Initialization
  
  init(sessionId: String, session: URLSessionTask, progressHandler: @escaping Requester.ProgressHandler,
       completionHandler: @escaping Requester.CompletionHandler) {
    self.session = session
    self.sessionId = sessionId
    self.progressHandler = progressHandler
    self.completionHandler = completionHandler
    self.status = .pending
    totalSize = 0
    data = Data()
  }
  
  // MARK: Public Functions
  
  /// Starts the request if it's pending
  open func start() {
    // If the session is already started or canceled, return
    if status != .pending { return }
    
    session.resume()
    status = .started
  }
  
  /// Cancels the request if it's started
  open func cancel() {
    // If the session is not started or is already canceled, return
    if status != .started { return }
    
    session.cancel()
    status = .canceled
  }
}


/// A singleton class that takes care of getting data. You can start a task
/// by calling `newTask(url:completionHandler:progressHandler)` and cancel
/// the request by using the `RequestHandler` instance returned
open class Requester {
  
  /// Completion handler type for when a request is completed. The first argument is
  /// the data and the second an error object. If the operation is successful, error
  /// is nil, otherwise data is nil.
  public typealias CompletionHandler = (Data?, Error?) -> Void
  
  /// Handler for reporting the progress of a request.
  public typealias ProgressHandler = (Double) -> Void
  
  /// Whether to auto start requests or not
  public var autostart: Bool
  
  /// Creates a default `URLCache` with common usage parameter values.
  open static let defaultURLCache: URLCache = {
    return URLCache(
      memoryCapacity: 20 * 1024 * 1024, // 20 MB
      diskCapacity: 150 * 1024 * 1024,  // 150 MB
      diskPath: "com.nozary.cachedrequester"
    )
  }()
  
  /// Creates a dictionary of http headers to be used while making requests
  open static let defaultHTTPHeaders: [AnyHashable: Any] = {
    // Accept-Encoding HTTP Header; see https://tools.ietf.org/html/rfc7230#section-4.2.3
    let acceptEncoding: String = "gzip;q=1.0, compress;q=0.5"
    
    // Accept-Language HTTP Header; see https://tools.ietf.org/html/rfc7231#section-5.3.5
    let acceptLanguage = Locale.preferredLanguages.prefix(6).enumerated().map { index, languageCode in
      let quality = 1.0 - (Double(index) * 0.1)
      return "\(languageCode);q=\(quality)"
      }.joined(separator: ", ")
    
    // The user agent for our framework
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    let userAgent = "CachedRequester/\(version) (com.nozary.cachedrequester; build:\(build); iOS 10.0.0) CachedRequester/\(version)"
    
    return [
      "Accept-Encoding": acceptEncoding,
      "Accept-Language": acceptLanguage,
      "User-Agent": userAgent
    ]
  }()
  
  
  /// Creates a default `URLSessionConfiguration` with common usage parameter values.
  ///
  /// - returns: The default `URLSessionConfiguration` instance.
  open static let defaultURLSessionConfiguration: URLSessionConfiguration = {
    let configuration = URLSessionConfiguration.default
    
    configuration.httpAdditionalHeaders = Requester.defaultHTTPHeaders
    configuration.httpShouldSetCookies = true
    configuration.httpShouldUsePipelining = false
    
    configuration.requestCachePolicy = .useProtocolCachePolicy
    configuration.allowsCellularAccess = true
    configuration.timeoutIntervalForRequest = 60
    
    configuration.urlCache = Requester.defaultURLCache
    
    return configuration
  }()
  
  /// The default `URLSession` that will be used by the framework
  private let defaultSession: URLSession
  
  /// The active tasks currently being handled by this class
  private var tasks: [RequestHandle]
  
  private let sessionDelegate: RequesterURLSessionDataDelegate
  
  // MARK: Initialization
  
  /// Since we need the cache to persist through out the app, we need to make the class a singleton
  public static let sharedInstance = Requester()
  
  
  /// Initializes an instance of `Requester` with default configurations
  private init() {
    tasks = [RequestHandle]()
    autostart = true
    sessionDelegate = RequesterURLSessionDataDelegate()
    defaultSession = URLSession(configuration: Requester.defaultURLSessionConfiguration, delegate: sessionDelegate,
                                delegateQueue: nil)
    sessionDelegate.responseReceived = responseReceived
    sessionDelegate.dataReceived = dataReceived
    sessionDelegate.completionHandler = requestCompleted
  }
  
  // MARK: Public Functions
  
  /// Creates and returns a RequestHandle. The value of `autostart` determines whether this function
  /// starts the task or not.
  ///
  /// - parameter url:                  The URL of the resource to get
  /// - parameter completionHandler:    A closure that's called when the request is completed
  /// - parameter progressHandler:      A closrue that's called periodically to report the progress of the request
  ///
  /// - returns:                        An instance of RequestHandle so that it can be canceled
  open func newTask(url: URL, completionHandler: @escaping CompletionHandler, progressHandler: @escaping ProgressHandler)
    -> RequestHandle {
      
      let dataTask = defaultSession.dataTask(with: url)
      let sessionId = self.sessionId(from: url.absoluteString)
      let requestHandle = RequestHandle(sessionId: sessionId, session: dataTask, progressHandler: progressHandler,
                                        completionHandler: completionHandler)
      self.tasks.append(requestHandle)
      
      if self.autostart {
        requestHandle.start()
      }
      
      return requestHandle
      
  }
  
  /// This function gets called when the first response is received from the server
  ///
  /// - parameter dataTask:             The `URLSessionDataTask` of the request
  /// - parameter contentLength:        The total expected length of the resource
  /// - parameter completionHandler:    `ResponseDisposition` completion handler
  open func responseReceived(_ dataTask: URLSessionDataTask, _ contentLength: UInt,
                             _ completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
    
    guard let requestHandle = requestHandle(from: dataTask) else {
      // for some reason the corresponding request handle was not found
      completionHandler(.cancel)
      return
    }
    
    requestHandle.totalSize = contentLength
    completionHandler(.allow)
    
  }
  
  /// This function is called when data is received. It's called periodically so
  /// we can calculate the progress of the request here.
  ///
  /// - parameter dataTask:           The `URLSessionDataTask` of the request
  /// - parameter data:               The data received
  open func dataReceived(_ dataTask: URLSessionDataTask, _ data: Data) {
    
    guard let requestHandle = requestHandle(from: dataTask) else {
      // for some reason the corresponding request handle was not found
      return
    }
    
    requestHandle.data.append(data)
    
    let currentSize = requestHandle.data.count
    let progress = requestHandle.totalSize > 0 ? Double(currentSize) / Double(requestHandle.totalSize) : 0
    
    // call the progress handler on the main queue
    DispatchQueue.main.async {
      requestHandle.progressHandler(progress)
    }
    
  }
  
  /// This function is called when the request is finished, either successfully, or it has failed.
  /// 
  /// - parameter dataTask:             The `URLSessionDataTask` of the request
  /// - parameter error:                In case the request has failed `error` is not nil and contains an error description
  open func requestCompleted(_ dataTask: URLSessionDataTask, _ error: Error?) {
    
    guard let requestHandle = requestHandle(from: dataTask) else {
      // for some reason the corresponding request handle was not found
      return
    }
    
    // call the handlers on the main queue
    DispatchQueue.main.async {
      requestHandle.progressHandler(1.0)
      requestHandle.completionHandler(requestHandle.data, error)
    }
    requestHandle.status = .finished
    
  }
  
  // MARK: Private functions
  
  /// Takes a `URLSessionTask` and returns the corresponding `RequestHandle` from the `tasks` list
  ///
  /// - parameter dataTask:     The data task to find its `RequestHandle`
  ///
  /// - returns:                The corresponding `RequestHandle` or nil if not found
  fileprivate func requestHandle(from dataTask: URLSessionDataTask) -> RequestHandle? {
    for task in tasks {
      if task.session == dataTask {
        return task
      }
    }
    
    // A request handle with that data task was not found
    return nil
  }
  
  /// Returns a session id. If this function is called inside the synchronization queue (sync)
  /// it ensures a unique value even if the random value is repeated
  ///
  /// - parameter url:        The url of the request
  ///
  /// - returns:              A [unique] session id
  fileprivate func sessionId(from url: String) -> String {
    return String(format: "%@-%f-%08x", url, Date().timeIntervalSince1970, arc4random())
  }
  
}


// MARK: URLSession Data Delegate

/// This class will be delegate of our session and will pass along the events to
/// our instance of `Requester`
class RequesterURLSessionDataDelegate: NSObject, URLSessionDataDelegate {
  
  /// Called when the initial response is received form the server
  public var responseReceived: ((URLSessionDataTask, UInt, @escaping (URLSession.ResponseDisposition) -> Void) -> Void)?
  
  /// Called each time a chunk of data is received
  public var dataReceived: ((URLSessionDataTask, Data) -> Void)?
  
  /// Called when the request has completed
  public var completionHandler: ((URLSessionDataTask, Error?) -> Void)?
  
  public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                         completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
    
    if let responseRecieved = self.responseReceived {
      responseRecieved(dataTask, UInt(response.expectedContentLength), completionHandler)
    }
    
  }
  
  public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    
    if let dataReceived = self.dataReceived {
      dataReceived(dataTask, data)
    }
    
  }
  
  public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    
    if let completionHandler = self.completionHandler, let dataTask = task as? URLSessionDataTask {
      completionHandler(dataTask, error)
    }
    
  }
  
}
