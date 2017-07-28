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
    
    fileprivate init() {
        retryCount = 1
        timeoutInterval = TimeInterval.infinity
    }
}

public extension HMNetworkRequest {
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
        public func with(endPoint: String) -> Builder {
            request.endPointStr = endPoint
            return self
        }
        
        /// Set the baseUrl.
        ///
        /// - Parameter baseUrl: A String value.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with(baseUrl: String) -> Builder {
            request.baseUrlStr = baseUrl
            return self
        }
        
        /// Set the endPoint and baseUrl using a resource type.
        ///
        /// - Parameter resource: A HMNetworkResourceType instance.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with(resource: HMNetworkResourceType) -> Builder {
            do {
                return try self
                    .with(baseUrl: resource.baseUrl())
                    .with(endPoint: resource.endPoint())
            } catch {
                return self
            }
        }
        
        /// Set the HTTP method.
        ///
        /// - Parameter method: A HttpMethod instance.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with(method: HttpMethod) -> Builder {
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
        public func with(headers: [String : String]) -> Builder {
            request.httpHeaders = headers
            return self
        }
        
        /// Set the body.
        ///
        /// - Parameter body: Any object.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with(body: Any) -> Builder {
            request.httpBody = body
            return self
        }
        
        /// Set the retryCount.
        ///
        /// - Parameter retries: An Int value.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with(retries: Int) -> Builder {
            request.retryCount = retries
            return self
        }
        
        public func build() -> HMNetworkRequest {
            return request
        }
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
    
    public func params() throws -> [String : Any]? {
        return httpParams
    }
    
    public func headers() throws -> [String : String]? {
        return httpHeaders
    }
    
    public func body() throws -> Any? {
        return httpBody
    }
    
    public func timeout() throws -> TimeInterval {
        return timeoutInterval
    }
    
    public func urlRequest() throws -> URLRequest {
        let method = try self.method()
        var request = try baseUrlRequest()
        
        switch method {
        case .post, .put:
            if let body = try self.body() {
                request.httpBody = try? JSONSerialization.data(
                    withJSONObject: body,
                    options: .prettyPrinted
                )
            }
            
        default:
            break
        }
        
        return request
    }
    
    public func retries() -> Int {
        return Swift.max(retryCount, 1)
    }
}
