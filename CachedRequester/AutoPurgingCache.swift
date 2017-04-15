//
//  AutoPurgingCache.swift
//  CachedRequester
//
//  Created by Milad on 4/15/17.
//  Copyright © 2017 Milad Nozary. All rights reserved.
//

import Foundation


// MARK: CacheItem

private class CacheItem {
  
  /// The key of the item
  let key: String
  
  /// The data to be cached
  let data: Data
  
  /// The time at which this cache entry was last used. Used 
  /// for purging the least used cache entries.
  var lastAccessed: TimeInterval
  
  // MARK: Initizalizers
  init(key: String, data: Data, lastAccessed: TimeInterval) {
    
    self.key = key
    self.data = data
    self.lastAccessed = lastAccessed
    
  }

  
}

/// An auto-purging in-memory cache. This class takes care of data caching
/// and removes least used items if a set memory limit is reached.
class AutoPurgingCache {
  
  // MARK: Properties
  
  /// The allowed size of this cache
  public var memoryLimit: Int
  
  /// The memory size to reach when purging least used data
  public var memorySizeAfterPurge: Int
  
  
  /// The Cache
  private var cache = [String: CacheItem]()
  
  /// The current size of the cache
  private var cacheSize: Int = 0
  
  
  // MARK: Initialization
  
  /// Constructor: Enforces Singleton
  init(memoryLimit: Int = 200 * 1024 * 1024, memorySizeAfterPurge: Int = 150 * 1024 * 1024) {
    self.memoryLimit = memoryLimit
    self.memorySizeAfterPurge = memorySizeAfterPurge
    
    // In case we received a memory warning, we need to pruge the cache completely
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(removeAll),
      name: Notification.Name.UIApplicationDidReceiveMemoryWarning,
      object: nil
    )
  }
  
  /// Deinitialize the class
  deinit {
    NotificationCenter.default.removeObserver(
      self,
      name: Notification.Name.UIApplicationDidReceiveMemoryWarning,
      object: nil
    )
  }

  
  // MARK: Public Function
  
  /// Adds a new item to the cache. Purges least used data if memory limit has reached
  ///
  /// - parameter key:              A unique key to identify this entry
  /// - parameter data:             The data to be cached
  public func add(key: String, data: Data) {
    
    let item = CacheItem(key: key, data: data, lastAccessed: Date().timeIntervalSince1970)
    cache[key] = item
    cacheSize += data.count
    
    // purge least used items if memory limit has been reached
    purgeLeastUsed()
    
  }
  
  /// Returns the data cached for `key` if available, and sets the access time
  ///
  /// - parameter key:            The key of the entry
  ///
  /// - returns:                  The data if available, `nil` otherwise
  public func get(key: String) -> Data? {
    
    guard let item = cache[key] else { return nil }
    
    item.lastAccessed = Date().timeIntervalSince1970
    
    return item.data
    
  }
  
  /// Removes a specific item from the cache
  /// 
  /// - parameter key:             The key of the cache item
  public func remove(key: String) {
    
    guard let item = cache[key] else { return }
    
    cacheSize -= item.data.count
    
    cache.removeValue(forKey: key)
    
  }
  
  /// Removes all items from the cache
  @objc
  public func removeAll() {
    
    cache.removeAll()
    cacheSize = 0
    
  }

  /// Checks the cache size and if it's bigger than `memorySizeAfterPurge`
  /// starts removing items from the cache until the cache size reaches 
  /// below that value.
  public func purgeLeastUsed() {
    
    // We don't wanna purge anything if memory limit hasn't been reached
    if cacheSize < memoryLimit {
      return
    }
    
    // sort the items by last accessed time
    let items = Array(cache.values).sorted { (item1, item2) -> Bool in
      return item1.lastAccessed < item2.lastAccessed
    }
    
    for item in items {
      
      guard cache[item.key] != nil else { continue }
      
      // check to see if the memory limit after purge has reached. We check first before removing 
      // anything so that if this functions is called and we're in the safe zone, no items are removed
      if cacheSize <= memorySizeAfterPurge {
        break
      }
      
      cacheSize -= item.data.count
      cache.removeValue(forKey: item.key)
      
    }
    
  }
  
}
