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
enum Result {
    case Success()
    case Error(NSError?)  // Error can be nil, in which case just output "unknown error".


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
}


// Return value from functions. Returns Success(value) if OK, Error(NSError) if not.
enum ResultOf<T> {
    case Success(FailableValueWrapper<T>)
    case Error(NSError?)  // Error can be nil, in which case just output "unknown error".
    
    // Initialise with the value directly, to hide the use of the wrapper.
    init(_ value: T) {
        self = .Success(FailableValueWrapper(value))
    }
    
    init(_ error: NSError) {
        self = .Error(error)
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

    
}




// Takes a collection of objects and a function to call on each one of them.
// Returns success only if all the function calls returned success.
// If any of them returns Error, then return immediately with that error.
func eachOf<T: SequenceType>(seq: T, fnc: (Int, T.Generator.Element) -> Result) -> Result {
    for (i, s) in enumerate(seq) {
        switch fnc(i, s) {
        case .Error(let e): return .Error(e)
        default: break // do nothing. Continue to next iteration of the sequence.
        }
    }
    return .Success() // Only return success if all of the f(s) performed successfully.
}



