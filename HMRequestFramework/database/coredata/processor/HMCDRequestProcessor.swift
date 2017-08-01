//
//  HMCDRequestProcessor.swift
//  HMRequestFramework
//
//  Created by Hai Pham on 20/7/17.
//  Copyright © 2017 Holmusk. All rights reserved.
//

import CoreData
import RxSwift
import SwiftUtilities

/// CoreData request processor class. We skip the handler due to CoreData
/// design limitations. This way, casting is done at the database level.
public struct HMCDRequestProcessor {
    fileprivate var manager: HMCDManager?
    fileprivate var rqMiddlewareManager: HMMiddlewareManager<Req>?
    
    fileprivate init() {}
    
    fileprivate func coreDataManager() -> HMCDManager {
        if let manager = self.manager {
            return manager
        } else {
            fatalError("CoreData manager cannot be nil")
        }
    }
}

extension HMCDRequestProcessor: HMCDRequestProcessorType {
    public typealias Req = HMCDRequest
    
    /// Override this method to provide default implementation.
    ///
    /// - Returns: A HMMiddlewareManager instance.
    public func requestMiddlewareManager() -> HMMiddlewareManager<Req>? {
        return rqMiddlewareManager
    }
    
    /// Override this method to provide default implementation.
    ///
    /// - Parameter request: A Req instance.
    /// - Returns: An Observable instance.
    /// - Throws: Exception if no context is available.
    public func executeTyped<Val>(_ request: Req) throws -> Observable<Try<Val>>
        where Val: NSFetchRequestResult
    {
        let operation = try request.operation()
        
        switch operation {
        case .fetch:
            return try executeFetch(request, Val.self)
            
        default:
            throw Exception("Please use normal execute for void return values")
        }
    }
    
    /// Perform a CoreData get request.
    ///
    /// - Parameters:
    ///   - request: A Req instance.
    ///   - cls: The Val class type.
    /// - Returns: An Observable instance.
    /// - Throws: Exception if the execution fails.
    private func executeFetch<Val>(_ request: Req, _ cls: Val.Type) throws
        -> Observable<Try<Val>>
        where Val: NSFetchRequestResult
    {
        let manager = coreDataManager()
        let cdRequest: NSFetchRequest<Val> = try request.fetchRequest()
    
        return manager.rx.fetch(cdRequest)
            .retry(request.retries())
            .map(Try<Val>.success)
            .catchErrorJustReturn(Try<Val>.failure)
    }
    
    /// Override this method to provide default implementation.
    ///
    /// - Parameter request: A Req instance.
    /// - Returns: An Observable instance.
    /// - Throws: Exception if the execution fails.
    public func execute(_ request: Req) throws -> Observable<Try<Void>> {
        let operation = try request.operation()
        
        switch operation {
        case .saveInMemory:
            return try executeSaveInMemory(request)
            
        case .persistToFile:
            return try executePersistToFile(request)
            
        case .delete:
            return try executeDelete(request)
            
        case .upsert:
            return try executeUpsert(request)
            
        case .fetch:
            throw Exception("Please use typed execute for typed return values")
        }
    }
    
    /// Perform a CoreData data in-memory persistence operation.
    ///
    /// - Parameter request: A Req instance.
    /// - Returns: An Observable instance.
    /// - Throws: Exception if the execution fails.
    private func executeSaveInMemory(_ request: Req) throws -> Observable<Try<Void>> {
        let manager = coreDataManager()
        let data = try request.dataToSave()
            
        return manager.rx.saveInMemory(data)
            .retry(request.retries())
            .map(Try.success)
            .catchErrorJustReturn(Try.failure)
    }
    
    /// Perform a CoreData data persistence operation.
    ///
    /// - Parameter request: A Req instance.
    /// - Returns: An Observable instance.
    /// - Throws: Exception if the execution fails.
    private func executePersistToFile(_ request: Req) throws -> Observable<Try<Void>> {
        let manager = coreDataManager()
        
        return manager.rx.persistAllChangesToFile()
            .retry(request.retries())
            .map(Try.success)
            .catchErrorJustReturn(Try.failure)
    }
    
    /// Perform a CoreData data delete operation.
    ///
    /// - Parameter request: A Req instance.
    /// - Returns: An Observable instance.
    /// - Throws: Exception if the execution fails.
    private func executeDelete(_ request: Req) throws -> Observable<Try<Void>> {
        let manager = coreDataManager()
        let data = try request.dataToDelete()
        
        return manager.rx.deleteFromMemory(data)
            .retry(request.retries())
            .map(Try.success)
            .catchErrorJustReturn(Try.failure)
    }
    
    /// Perform a CoreData upsert operation.
    ///
    /// - Parameter request: A Req instance.
    /// - Returns: An Observable instance.
    /// - Throws: Exception if the execution fails.
    private func executeUpsert(_ request: Req) throws -> Observable<Try<Void>> {
        let manager = coreDataManager()
        let data = try request.dataToUpsert()
        let predicate = manager.predicateForUpsertableFetch(data)
        
        let fetchRequest = request.cloneBuilder()
            .with(predicate: predicate)
            .with(sortDescriptors: [])
            .build()
        
        return try executeFetch(fetchRequest, NSManagedObject.self)
            .toArray().map({$0.flatMap({$0.value})})
            .flatMap({(objs: [NSManagedObject]) -> Observable<Try<Void>> in
                let insertObjs: [HMCDUpsertableObject] = data
                var deleteObjs: [NSManagedObject] = []
                
                for obj in objs {
                    if let datum = data.first(where: {
                        let key = $0.primaryKey()
                        let value = $0.primaryValue()
                        print("KEY \(key) VALUE \(value)")
                        return obj.value(forKey: key) as? String == value
                    }) {
                        print(datum)
                        deleteObjs.append(obj)
                    }
                }
                
                return Observable
                    .concat(
                        try self.execute(request.cloneBuilder()
                            .with(operation: .delete)
                            .with(dataToDelete: deleteObjs)
                            .build()),
                        
                        try self.execute(request.cloneBuilder()
                            .with(operation: .persistToFile)
                            .with(dataToSave: insertObjs)
                            .build())
                    )
                    .toArray()
                    .map(toVoid)
                    .map(Try.success)
            })
            .catchErrorJustReturn(Try.failure)
    }
}

extension HMCDRequestProcessor: HMBuildableType {
    public static func builder() -> Builder {
        return Builder()
    }
    
    public final class Builder {
        public typealias Req = HMCDRequestProcessor.Req
        fileprivate var processor: Buildable
        
        fileprivate init() {
            processor = Buildable()
        }
        
        /// Set the manager instance.
        ///
        /// - Parameter manager: A HMCDManager instance.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with(manager: HMCDManager) -> Self {
            processor.manager = manager
            return self
        }
        
        /// Set the request middleware manager.
        ///
        /// - Parameter rqMiddlewareManager: A HMMiddlewareManager instance.
        /// - Returns: The current Builder instance.
        @discardableResult
        public func with(rqMiddlewareManager: HMMiddlewareManager<Req>?) -> Self {
            processor.rqMiddlewareManager = rqMiddlewareManager
            return self
        }
    }
}

extension HMCDRequestProcessor.Builder: HMBuilderType {
    public typealias Buildable = HMCDRequestProcessor
    
    /// Override this method to provide default implementation.
    ///
    /// - Parameter buildable: A Buildable instance.
    /// - Returns: The current Builder instance.
    @discardableResult
    public func with(buildable: Buildable) -> Self {
        return self
            .with(manager: buildable.coreDataManager())
            .with(rqMiddlewareManager: buildable.requestMiddlewareManager())
    }
    
    public func build() -> Buildable {
        return processor
    }
}
