//
//  Result.swift
//  PicSplitter
//
//  Created by Patrick Wallace on 31/12/2014.
//  Copyright (c) 2014 Patrick Wallace. All rights reserved.
//

import Foundation

// This is a workaround-wrapper class for a bug in the Swift compiler. DO NOT USE THIS CLASS!
// Swift needs to know the size of an enum at compile time, so instead of <T> which can be any value
// we use pointer-to-wrapper-class<T>, which is always the size of a pointer.
public class FailableValueWrapper<T> {
    public let value: T
    public init(_ value: T) { self.value = value }
}

// Return status from a function. Returns Success() if OK, Error(NSError) if not.
public enum Result {
    case Success()
    case Error(NSError)  // If the error is nil, we will substitute a default NSError object.

    // True if the result was a success, false if it failed.
    var success: Bool {
        switch self {
        case .Success: return true
        case .Error: return false
        }
    }
    
    // Returns the error if we were in an error state, or nil otherwise.
    var error: NSError? {
        switch self {
        case .Error(let e): return e
        default: return nil
        }
    }

    // Performs the function fn on this object, if it has a valid value.
    // If not, just propagates the error.
    func map<U>(fn: Void -> ResultOf<U>) -> ResultOf<U> {
        switch self {
        case .Success(): return fn()
        case .Error(let e): return .Error(e)
        }
    }
    
    // As map(), but returns a value with no data, i.e. only success and fail options.
    func map0(fn: Void -> Result) -> Result {
        switch self {
        case .Success(let w): return fn()
        case .Error(let e): return .Error(e)
        }
    }
    
    // If an error was found, run the given handler, passing the error in.
    // Useful when we only want to handle errors, but no need to handle the success case.
    func onError(handler: (NSError) -> Void ) {
        switch self {
        case .Error(var error):
            handler(error)
        case .Success():
            break
        }
    }
}


// Return value from functions. Returns Success(value) if OK, Error(NSError) if not.
public enum ResultOf<T> {
    case Success(FailableValueWrapper<T>)
    case Error(NSError)  // We will substitute a default error if the one provided is nil.
    
    // Initialise with the value directly, to hide the use of the wrapper.
    init(_ value: T) {
        self = .Success(FailableValueWrapper(value))
    }
    
    init(_ error: NSError) {
        self = .Error(error)
    }
    
    // True if the result was a success, false if it failed.
    var success: Bool {
        switch self {
        case .Success: return true
        case .Error: return false
        }
    }
    
    // Returns the error if we were in an error state, or nil otherwise.
    var error: NSError? {
        switch self {
        case .Error(let e): return e
        default: return nil
        }
    }


    // Performs the function fn on this object, if it has a valid value.
    // If not, just propagates the error.
    func map<U>(fn: T -> ResultOf<U>) -> ResultOf<U> {
        switch self {
        case .Success(let w): return fn(w.value)
        case .Error(let e): return .Error(e)
        }
    }

    // As map(), but returns a value with no data, i.e. only success and fail options.
    func map0(fn: T -> Result) -> Result {
        switch self {
        case .Success(let w): return fn(w.value)
        case .Error(let e): return .Error(e)
        }
    }

    // Boolean result: If successful it returns .Success(), 
    // if it failed, return the error code. 
    // Useful if we care that it succeeded, but don't need the returned value.
    public var result: Result {
        switch self {
        case .Success(_): return .Success()
        case .Error(let e): return .Error(e)
        }
    }
}




// Takes a collection of objects and a function to call on each one of them.
// Returns success only if all the function calls returned success.
// If any of them returns Error, then return immediately with that error.
public func eachOf<T: SequenceType>(seq: T, fnc: (Int, T.Generator.Element) -> Result) -> Result {
    for (i, s) in enumerate(seq) {
        switch fnc(i, s) {
        case .Error(let e): return .Error(e)
        default: break // do nothing. Continue to next iteration of the sequence.
        }
    }
    return .Success() // Only return success if all of the f(s) performed successfully.
}

// Wrap any function that doesn't return anything, so it returns Success().
public func alwaysOk<T>(fnc: (t: T) -> Void) -> ((t: T) -> Result) {
    return { fnc(t: $0)
        return .Success()
    }
}

// Given two values of type ResultOf<T>, if both are successful, return the results as a tuple. If either fails, then return the error.
public func and<T,U>(r1: ResultOf<T>, r2: ResultOf<U>) -> ResultOf<(T,U)> {
    typealias TupleT = (T, U)
    switch r1 {
    case .Success(let a1):
        switch r2 {
        case .Success(let a2):
            let tuple = (a1.value, a2.value)
            let wrapper = FailableValueWrapper<TupleT>(tuple)
            return .Success(wrapper)
        case .Error(let e): return .Error(e)
        }
    case .Error(let e): return .Error(e)
    }
}

/// Return success only if r1 and r2 both succeed. Otherwise return the first value that failed.
public func and(r1: Result, r2: Result) -> Result {
    if !r1.success {
        return r1
    } else if !r2.success {
        return r2
    } else {
        return .Success()
    }
}
