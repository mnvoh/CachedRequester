//
//  CachedRequesterTests.swift
//  CachedRequesterTests
//
//  Created by Milad on 4/14/17.
//  Copyright © 2017 Milad Nozary. All rights reserved.
//

import XCTest
@testable import CachedRequester

class CachedRequesterTests: XCTestCase {
  
  var cache: AutoPurgingCache?
  
  override func setUp() {
    
    super.setUp()
    
    cache = AutoPurgingCache(memoryLimit: 2 * 1024 * 1024, memorySizeAfterPurge: 2 * 1024 * 1024)
    
  }
  
  override func tearDown() {
    
    cache = nil
    
    super.tearDown()
    
  }
  
  func testInitialConfiguration() {
    
    let requester = Requester.sharedInstance
    XCTAssertGreaterThan(requester.inMemoryCacheSizeLimit, 1024 * 1024, "Insufficient memory limit")
    XCTAssertGreaterThan(requester.inMemoryCacheSizeLimitAfterPurge, 1024 * 1024, "Insufficient memory limit")
    
  }
  
  /// The following two tests are related. The function names for `testRequesterWithInitialRequest`
  /// and `testRequesterWithSecondRequest` are chosen to be sorted alphabetically so that 
  /// `testRequesterWithSecondRequest` runs after `testRequesterWithInitialRequest`.
  func testRequesterWithInitialRequest() {
    
    // given
    let requester = Requester.sharedInstance
    let url = URL(string: "http://pastebin.com/raw/wgkJgazE")!
    let promise = expectation(description: "Network request succeeds")
    
    // when
    let task = requester.newTask(url: url, completionHandler: { (data, error) in
      // then
      guard data != nil, error == nil else {
        XCTFail("\(error?.localizedDescription ?? "Unknown Error")")
        return
      }
      
      promise.fulfill()
    }) { (progress) in }
    
    waitForExpectations(timeout: 10, handler: nil)
    
    XCTAssertNotNil(task)
  }
  
  /// Since we made another request first in `testRequesterWithInitialRequest` in this test
  /// we expect to get a `nil` value for task, which means the data have been loaded from cache
  func testRequesterWithSecondRequest() {
    
    // given
    let requester = Requester.sharedInstance
    let url = URL(string: "http://pastebin.com/raw/wgkJgazE")!
    let promise = expectation(description: "Network request succeeds from cache")
    
    // when
    let task = requester.newTask(url: url, completionHandler: { (data, error) in
      // then
      guard data != nil, error == nil else {
        XCTFail("\(error?.localizedDescription ?? "Unknown Error")")
        return
      }
      
      promise.fulfill()
    }) { (progress) in }
    
    waitForExpectations(timeout: 1, handler: nil)
    
    XCTAssertNil(task)
    
  }
  
  func testCacheStoringAndRetrieving() {
    
    // given
    let data = String(repeating: "M", count: 1024).data(using: .utf8)!
    let key = "dummydata"
    
    // when
    cache?.add(key: key, data: data)
    
    // then
    XCTAssertNotNil(cache?.get(key: key))
    
  }
  
  
  func testCacheDeleting() {
    
    // given
    let data = String(repeating: "M", count: 1024).data(using: .utf8)!
    let key = "dummydata"
    cache?.add(key: key, data: data)
    let cacheSize = (cache?.cacheSize)!
    
    // when 
    cache?.remove(key: key)
    
    // then
    XCTAssertLessThan((cache?.cacheSize)!, cacheSize)
    
  }
  
  func testCachePurging() {
    
    // given
    let data = String(repeating: "M", count: 1024).data(using: .utf8)!
    let key = "dummydata"
    cache?.add(key: key, data: data)
    
    // when 
    cache?.removeAll()
    
    // then
    XCTAssertEqual((cache?.cacheSize)!, 0)
  }
  
  
  func testCachePerformance() {
    
    var data = [Data]()
    
    for _ in 0..<100 {
      
      let datum = String(repeating: "M", count: Int(arc4random()) % 102400).data(using: .utf8)!
      data.append(datum)
      
    }
    
    self.measure {
      for (index, item) in data.enumerated() {
        let key = "KEY\(index)"
        self.cache?.add(key: key, data: item)
        self.cache?.remove(key: key)
      }
    }
    
  }
  
}
