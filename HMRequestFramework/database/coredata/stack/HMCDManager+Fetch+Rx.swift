//
//  HMCDManager+Fetch.swift
//  HMRequestFramework
//
//  Created by Hai Pham on 8/9/17.
//  Copyright © 2017 Holmusk. All rights reserved.
//

import CoreData
import RxSwift
import SwiftUtilities

public extension HMCDManager {
    
    /// Get the predicate to search for records related to a Sequence of
    /// identifiables.
    ///
    /// - Parameter data: A Sequence of HMCDIdentifiableType.
    /// - Returns: A NSPredicate instance.
    public func predicateForIdentifiableFetch<S>(_ identifiables: S)
        -> NSPredicate where
        S: Sequence, S.Iterator.Element: HMCDIdentifiableType
    {
        return NSCompoundPredicate(orPredicateWithSubpredicates:
            identifiables
                .map({($0.primaryKey(), $0.primaryValue())})
                .filter({$0.1 != nil})
                .map({NSPredicate(format: "%K == %@", $0.0, $0.1 ?? "")})
        )
    }
}

public extension HMCDManager {
    
    /// Fetch data using a request. This operation blocks.
    ///
    /// - Parameter request: A NSFetchRequest instance.
    /// - Returns: An Array of NSManagedObject.
    /// - Throws: Exception if the fetch fails.
    public func blockingFetch<Val>(_ request: NSFetchRequest<Val>) throws -> [Val] {
        return try blockingFetch(disposableObjectContext(), request)
    }
    
    /// Fetch data using a request and a specified Val class. This operation blocks.
    ///
    /// - Parameters:
    ///   - request: A NSFetchRequest instance.
    ///   - cls: A Val class type.
    /// - Returns: An Array of NSManagedObject.
    /// - Throws: Exception if the fetch fails.
    public func blockingFetch<Val>(_ request: NSFetchRequest<Val>,
                                   _ cls: Val.Type) throws -> [Val] {
        return try blockingFetch(request)
    }
    
    /// Fetch data from a context using a request. This operation blocks.
    ///
    /// - Parameters:
    ///   - context: A NSManagedObjectContext instance.
    ///   - request: A NSFetchRequest instance.
    /// - Returns: An Array of NSManagedObject.
    /// - Throws: Exception if the fetch fails.
    public func blockingFetch<Val>(_ context: NSManagedObjectContext,
                                   _ request: NSFetchRequest<Val>) throws
        -> [Val]
    {
        return try context.fetch(request)
    }
    
    /// Fetch data from a context using a request and a specified Val class.
    /// This operation blocks.
    ///
    /// - Parameters:
    ///   - context: A NSManagedObjectContext instance.
    ///   - request: A NSFetchRequest instance.
    ///   - cls: A Val class type.
    /// - Returns: An Array of NSManagedObject.
    /// - Throws: Exception if the fetch fails
    public func blockingFetch<Val>(_ context: NSManagedObjectContext,
                                   _ request: NSFetchRequest<Val>,
                                   _ cls: Val.Type) throws -> [Val] {
        return try blockingFetch(context, request)
    }
    
    /// Fetch data from a context using a request and a specified PureObject class.
    /// This operation blocks.
    ///
    /// - Parameters:
    ///   - context: A NSManagedObjectContext instance.
    ///   - request: A NSFetchRequest instance.
    ///   - cls: A PO class type.
    /// - Returns: An Array of NSManagedObject.
    /// - Throws: Exception if the fetch fails
    public func blockingFetch<PO>(_ context: NSManagedObjectContext,
                                  _ request: NSFetchRequest<PO.CDClass>,
                                  _ cls: PO.Type) throws -> [PO.CDClass]
        where PO: HMCDPureObjectType
    {
        return try blockingFetch(context, request, cls.CDClass.self)
    }
    
    /// Refetch some NSManagedObject from DB.
    ///
    /// - Parameters:
    ///   - context: A NSManagedObjectContext instance.
    ///   - data: A Sequence of NSManagedObject.
    /// - Returns: An Array of NSManagedObject.
    /// - Throws: Exception if the fetch fails.
    public func blockingRefetch<S>(_ context: NSManagedObjectContext,
                                   _ data: S) throws
        -> [NSManagedObject] where
        S: Sequence, S.Iterator.Element: NSManagedObject
    {
        return try data.map({$0.objectID}).flatMap(context.existingObject)
    }
    
    /// Fetch objects from DB whose primary key values correspond to those
    /// supplied by the specified identifiables objects.
    ///
    /// - Parameters:
    ///   - context: A NSManagedObjectContext instance.
    ///   - entityName: A String value representing the entity's name.
    ///   - identifiables: A Sequence of HMCDIdentifiableType.
    /// - Returns: An Array of NSManagedObject.
    /// - Throws: Exception if the fetch fails.
    public func blockingRefetch<U,S>(_ context: NSManagedObjectContext,
                                     _ entityName: String,
                                     _ identifiables: S) throws -> [U] where
        U: NSFetchRequestResult,
        U: HMCDIdentifiableType,
        S: Sequence,
        S.Iterator.Element == U
    {
        let data = identifiables.map({$0})
        
        if data.isNotEmpty {
            let predicate = predicateForIdentifiableFetch(data)
            let request: NSFetchRequest<U> = NSFetchRequest(entityName: entityName)
            request.predicate = predicate
            return try blockingFetch(context, request)
        } else {
            return []
        }
    }
}

public extension Reactive where Base: HMCDManager {
    
    /// Get data for a fetch request.
    ///
    /// - Parameters:
    ///   - context: A NSManagedObjectContext instance.
    ///   - request: A NSFetchRequest instance.
    /// - Returns: An Observable instance.
    public func fetch<Val>(_ context: NSManagedObjectContext,
                           _ request: NSFetchRequest<Val>) -> Observable<[Val]> {
        let base = self.base
        
        return Observable.create({(obs: AnyObserver<[Val]>) in
            do {
                let result = try base.blockingFetch(context, request)
                obs.onNext(result)
                obs.onCompleted()
            } catch let e {
                obs.onError(e)
            }
            
            return Disposables.create()
        })
    }
    
    /// Get data for a fetch request.
    ///
    /// - Parameters:
    ///   - context: A NSManagedObjectContext instance.
    ///   - request: A NSFetchRequest instance.
    ///   - cls: A Val class type.
    /// - Returns: An Observable instance.
    public func fetch<Val>(_ context: NSManagedObjectContext,
                           _ request: NSFetchRequest<Val>,
                           _ cls: Val.Type) -> Observable<[Val]> {
        return fetch(context, request)
    }
    
    /// Get data for a fetch request.
    ///
    /// - Parameters:
    ///   - context: A NSManagedObjectContext instance.
    ///   - request: A NSFetchRequest instance.
    ///   - cls: A PO class type.
    /// - Returns: An Observable instance.
    public func fetch<PO>(_ context: NSManagedObjectContext,
                          _ request: NSFetchRequest<PO.CDClass>,
                          _ cls: PO.Type) -> Observable<[PO.CDClass]>
        where PO: HMCDPureObjectType
    {
        return fetch(context, request, cls.CDClass.self)
    }
    
    /// Get data for a fetch request.
    ///
    /// - Parameters request: A NSFetchRequest instance.
    /// - Returns: An Observable instance.
    public func fetch<Val>(_ request: NSFetchRequest<Val>) -> Observable<[Val]> {
        return fetch(base.disposableObjectContext(), request)
    }
    
    /// Get data for a fetch request.
    ///
    /// - Parameters:
    ///   - request: A NSFetchRequest instance.
    ///   - cls: A Val class type.
    /// - Returns: An Observable instance.
    public func fetch<Val>(_ request: NSFetchRequest<Val>,
                           _ cls: Val.Type) -> Observable<[Val]> {
        return fetch(request)
    }
    
    /// Get data for a fetch request.
    ///
    /// - Parameters:
    ///   - request: A NSFetchRequest instance.
    ///   - cls: A PO class type.
    /// - Returns: An Observable instance.
    public func fetch<PO>(_ request: NSFetchRequest<PO.CDClass>,
                          _ cls: PO.Type) -> Observable<[PO.CDClass]>
        where PO: HMCDPureObjectType
    {
        return fetch(request, cls.CDClass.self)
    }
    
    /// Perform a refetch request for a Sequence of identifiable objects.
    ///
    /// - Parameters:
    ///   - context: A NSManagedObjectContext instance.
    ///   - entityName: A String value representing the entity's name.
    ///   - identifiables: A Sequence of HMCDIdentifiableType.
    /// - Returns: An Observable instance.
    public func refetch<U,S>(_ context: NSManagedObjectContext,
                             _ entityName: String,
                             _ identifiables: S)
        -> Observable<[U]> where
        U: NSFetchRequestResult,
        U: HMCDIdentifiableType,
        S: Sequence,
        S.Iterator.Element == U
    {
        let base = self.base
        
        return Observable.create({(obs: AnyObserver<[U]>) in
            do {
                let result = try base.blockingRefetch(context, entityName, identifiables)
                obs.onNext(result)
                obs.onCompleted()
            } catch let e {
                obs.onError(e)
            }
            
            return Disposables.create()
        })
    }
    
    /// Perform a refetch request for a Sequence of identifiable objects, using
    /// the default fetch context.
    ///
    /// - Parameters:
    ///   - entityName: A String value representing the entity's name.
    ///   - identifiables: A Sequence of HMCDIdentifiableType.
    /// - Returns: An Observable instance.
    public func refetch<U,S>(_ entityName: String, _ identifiables: S)
        -> Observable<[U]> where
        U: NSFetchRequestResult,
        U: HMCDIdentifiableType,
        S: Sequence,
        S.Iterator.Element == U
    {
        return refetch(base.disposableObjectContext(), entityName, identifiables)
    }
}
