//
//  Set.swift
//  PicSplitter
//
//  Created by Patrick Wallace on 31/08/2014.
//  Copyright (c) 2014 Patrick Wallace. All rights reserved.
//

import Foundation

class Set<T where T: Hashable> : NSObject, NSCopying, SequenceType {
    
    // MARK: Instance Data
    private var _data : [T : Bool] = [:]
    
    // MARK: Constructors
    
    override init() {
        super.init()
    }
    
    init(array: [T]) {
        super.init()
        addFromArray(array)
    }
    
    init(set: Set<T>) {
        super.init()
        addFromArray(set.array)
    }
    
    // MARK: Methods
    
    func add(var item: T) {
        _data[item] = true
    }
    
    func addFromArray(var items: [T]) {
        for i in items {
            add(i)
        }
    }
    
    func addFromSet(var items: Set<T>) {
        addFromArray(items.array)
    }
    
    func remove(var item: T) {
        _data.removeValueForKey(item)
    }
    
    func removeFromArray(var items: [T]) {
        for i in items {
            remove(i)
        }
    }
    
    func removeFromSet(var items: Set<T>) {
        removeFromArray(items.array)
    }
    
    func removeAll() -> Set<T> {
        var oldData = copy() as Set<T>
        _data.removeAll(keepCapacity: false)
        return oldData
    }
    
    func contains(var item: T) -> Bool {
        return _data[item] != nil
    }
    
    var array: [T] {
        return [T](_data.keys)
    }
    
    // Returns a copy of this object containing only the entries where predicate(object) returns true.
    typealias Predicate = (T) -> Bool
    func filter(predicate: Predicate) -> Set<T> {
        var newSet = Set<T>()
        for object in self.array {
            if predicate(object) {
                newSet.add(object)
            }
        }
        return newSet
    }
    
    // MARK: NSCopying

    func copyWithZone(zone: NSZone) -> AnyObject {
        return Set<T>(array: [T](_data.keys))
    }
    
    // MARK: SequenceType
    
    func generate() -> Array<T>.Generator {
        return self.array.generate()
    }
}

