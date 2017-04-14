//
//  Requester.swift
//  CachedRequester
//
//  Created by Milad on 4/14/17.
//  Copyright © 2017 Milad Nozary. All rights reserved.
//

import Foundation

/// When making a request, an instance of this class will be returned so that the request
/// can be paused, canceled or resumed.
open class RequestHandle {
  
  /// The handle to the sesison of the data task
  open let session: URLSessionTask
  
  /// If the same request is made several times we need a unique identifier 
  /// to be able to cancel a specific one.
  open let sessionId: String
  
  init(session: URLSessionTask, sessionId: String) {
    self.session = session
    self.sessionId = sessionId
  }
  
}
