//
//  HMNetworkRequest.swift
//  HMRequestFramework
//
//  Created by Hai Pham on 20/7/17.
//  Copyright © 2017 Holmusk. All rights reserved.
//

import Foundation
import SwiftUtilities

/// Use this concrete class whenever a HMNetworkRequestType is needed.
public struct HMNetworkRequest {
    fileprivate var endPointStr: String?
    fileprivate var baseUrlStr: String?
    fileprivate var httpMethod: HttpMethod?
    fileprivate var httpParams: [String : Any]?
    fileprivate var httpHeaders: [String : String]?
    fileprivate var httpBody: Any?
    fileprivate var timeoutInterval: TimeInterval
    fileprivate var retryCount: Int
    fileprivate var middlewaresEnabled: Bool
    fileprivate var rqDescription: String?
    
    fileprivate init() {
        retryCount = 1
        middlewaresEnabled = false
        timeoutInterval = TimeInterval.infinity
    }
}

extension HMNetworkRequest: HMBuildableType {
    public static func builder() -> Builder {
        return Builder()
    }
    
    public final class Builder {
        fileprivate var request: HMNetworkRequest
        
        fileprivate init() {
            request = HMNetworkRequest()
        }
        
        /// Set the endpoint.
        ///
        /// - Parameter endPoint: A String value.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with(endPoint: String?) -> Builder {
            request.endPointStr = endPoint
            return self
        }
        
        /// Set the baseUrl.
        ///
        /// - Parameter baseUrl: A String value.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with(baseUrl: String?) -> Builder {
            request.baseUrlStr = baseUrl
            return self
        }
        
        /// Set the endPoint and baseUrl using a resource type.
        ///
        /// - Parameter resource: A HMNetworkResourceType instance.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with(resource: HMNetworkResourceType) -> Builder {
            return self
                .with(baseUrl: try? resource.baseUrl())
                .with(endPoint: try? resource.endPoint())
        }
        
        /// Set the HTTP method.
        ///
        /// - Parameter method: A HttpMethod instance.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with(method: HttpMethod?) -> Builder {
            request.httpMethod = method
            return self
        }
        
        /// Set the timeout.
        ///
        /// - Parameter timeout: A TimeInterval instance.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with(timeout: TimeInterval) -> Builder {
            request.timeoutInterval = timeout
            return self
        }
        
        /// Set the request params.
        ///
        /// - Parameter params: A Dictionary of params.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with(params: [String : Any]?) -> Builder {
            request.httpParams = params
            return self
        }
        
        /// Set the request headers.
        ///
        /// - Parameter headers: A Dictionary of headers.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with(headers: [String : String]?) -> Builder {
            request.httpHeaders = headers
            return self
        }
        
        /// Set the body.
        ///
        /// - Parameter body: Any object.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with(body: Any?) -> Builder {
            request.httpBody = body
            return self
        }
        
        /// Set the body.
        ///
        /// - Parameter jsonConvertible: A HMJSONConvertibleType instance.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with(jsonConvertible: HMJSONConvertibleType) -> Builder {
            return with(body: jsonConvertible.toJSON())
        }
    }
}

extension HMNetworkRequest: HMProtocolConvertibleType {
    public typealias PTCType = HMNetworkRequestType
    
    public func asProtocol() -> PTCType {
        return self as PTCType
    }
}

extension HMNetworkRequest.Builder: HMProtocolConvertibleBuilderType {
    public typealias Buildable = HMNetworkRequest
    
    /// Override this method to provide default implementation.
    ///
    /// - Parameter generic: A HMNetworkRequestType.
    /// - Returns: The current Builder instance.
    public func with(generic: Buildable.PTCType) -> Buildable.Builder {
        return self
            .with(baseUrl: try? generic.baseUrl())
            .with(endPoint: try? generic.endPoint())
            .with(method: try? generic.method())
            .with(body: try? generic.body())
            .with(headers: generic.headers())
            .with(params: generic.params())
            .with(timeout: generic.timeout())
            .with(retries: generic.retries())
            .with(applyMiddlewares: generic.applyMiddlewares())
            .with(requestDescription: generic.requestDescription())
    }
    
    /// Override this method to provide default implementation.
    ///
    /// - Parameter buildable: A HMNetworkRequest instance.
    /// - Returns: The current Builder instance.
    @discardableResult
    public func with(buildable: HMNetworkRequest) -> Buildable.Builder {
        return with(generic: buildable)
    }
}

extension HMNetworkRequest.Builder: HMRequestBuilderType {

    /// Override this method to provide default implementation.
    ///
    /// - Parameter retries: An Int value.
    /// - Returns: The current Builder instance.
    @discardableResult
    public func with(retries: Int) -> Buildable.Builder {
        request.retryCount = retries
        return self
    }
    
    /// Override this method to provide default implementation.
    ///
    /// - Parameter applyMiddlewares: A Bool value.
    /// - Returns: The current Builder instance.
    @discardableResult
    public func with(applyMiddlewares: Bool) -> Buildable.Builder {
        request.middlewaresEnabled = applyMiddlewares
        return self
    }
    
    /// Override this method to provide default implementation.
    ///
    /// - Parameter requestDescription: A String value.
    /// - Returns: The current Builder instance.
    @discardableResult
    public func with(requestDescription: String?) -> Buildable.Builder {
        request.rqDescription = requestDescription
        return self
    }
    
    public func build() -> Buildable {
        return request
    }
}

extension HMNetworkRequest: HMNetworkRequestType {
    public func endPoint() throws -> String {
        if let url = self.endPointStr {
            return url
        } else {
            throw Exception("Endpoint cannot be nil")
        }
    }
    
    public func baseUrl() throws -> String {
        if let baseUrl = self.baseUrlStr {
            return baseUrl
        } else {
            throw Exception("Base Url cannot be nil")
        }
    }
    
    public func method() throws -> HttpMethod {
        if let method = httpMethod {
            return method
        } else {
            throw Exception("Method cannot be nil")
        }
    }
    
    public func body() throws -> Any {
        if let body = httpBody {
            return body
        } else {
            throw Exception("Body cannot be nil")
        }
    }
    
    public func urlRequest() throws -> URLRequest {
        let method = try self.method()
        var request = try baseUrlRequest()
        
        switch method {
        case .post, .put:
            request.httpBody = try JSONSerialization.data(
                withJSONObject: try self.body(),
                options: .prettyPrinted)
            
        default:
            break
        }
        
        return request
    }
    
    public func params() -> [String : Any]? {
        return httpParams
    }
    
    public func headers() -> [String : String]? {
        return httpHeaders
    }
    
    public func timeout() -> TimeInterval {
        return timeoutInterval
    }
    
    public func retries() -> Int {
        return Swift.max(retryCount, 1)
    }
    
    public func applyMiddlewares() -> Bool {
        return middlewaresEnabled
    }
    
    public func requestDescription() -> String? {
        return rqDescription
    }
}

//extension HMNetworkRequest: CustomStringConvertible {
//    public var description: String {
//        let method = (try? self.method().rawValue) ?? "INVALID METHOD"
//        let url = (try? self.url().absoluteString) ?? "INVALID URL"
//        let description = (self.requestDescription()) ?? "NONE"
//        return "Performing \(method) at: \(url). Description: \(description)"
//    }
//}

