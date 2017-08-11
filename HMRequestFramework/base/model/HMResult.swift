//
//  HMResult.swift
//  HMRequestFramework
//
//  Created by Hai Pham on 8/10/17.
//  Copyright © 2017 Holmusk. All rights reserved.
//

import SwiftUtilities

/// Use this class to represent the result of some operation that is applied
/// to multiple items (e.g. in an Array), for which the result of each application
/// could be relevant to downstream flow.
public struct HMResult {
    public static func just(_ obj: Any) -> HMResult {
        return HMResult.builder().with(object: obj).build()
    }
    
    fileprivate var object: Any?
    fileprivate var error: Error?
    
    fileprivate init() {}
    
    public func appliedObject() -> Any? {
        return object
    }
    
    public func operationError() -> Error? {
        return error
    }
}

public extension HMResult {
    public func isSuccess() -> Bool {
        return error == nil
    }
    
    public func isFailure() -> Bool {
        return !isSuccess()
    }
}

extension HMResult: HMBuildableType {
    public static func builder() -> Builder {
        return Builder()
    }
    
    public final class Builder {
        fileprivate var result: HMResult
        
        fileprivate init() {
            result = HMResult()
        }
        
        /// Set the object to which the operation was applied.
        ///
        /// - Parameter object: A Val instance.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with(object: Any?) -> Self {
            result.object = object
            return self
        }
        
        /// Set the operation Error.
        ///
        /// - Parameter error: An Error instance.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with(error: Error?) -> Self {
            result.error = error
            return self
        }
    }
}

extension HMResult.Builder: HMBuilderType {
    public typealias Buildable = HMResult
    
    public func with(buildable: Buildable) -> Self {
        return self
            .with(object: buildable.object)
            .with(error: buildable.error)
    }
    
    public func build() -> Buildable {
        return result
    }
}
