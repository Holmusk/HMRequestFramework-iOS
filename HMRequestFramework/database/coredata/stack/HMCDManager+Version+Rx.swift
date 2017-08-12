//
//  HMCDManager+VersionExtension.swift
//  HMRequestFramework
//
//  Created by Hai Pham on 8/9/17.
//  Copyright © 2017 Holmusk. All rights reserved.
//

import CoreData
import RxSwift
import SwiftUtilities

// Just a bit of utility here, not going to expose publicly.
fileprivate extension HMVersionUpdateRequest where VC: HMCDIdentifiableType {
    
    /// Check if the current request possesses an edited object.
    ///
    /// - Parameter obj: A VC instance.
    /// - Returns: A Bool value.
    fileprivate func ownsEditedVC(_ obj: VC) -> Bool {
        return (try? editedVC().identifiable(as: obj)) ?? false
    }
}

public extension HMCDManager {
    
    /// Resolve version conflict using the specified strategy. This operation
    /// is not thread-safe.
    ///
    /// - Parameters:
    ///   - context: A NSManagedObjectContext instance.
    ///   - request: A HMVersionUpdateRequest instance.
    /// - Throws: Exception if the operation fails.
    func resolveVersionConflictUnsafely<VC>(
        _ context: NSManagedObjectContext,
        _ request: HMVersionUpdateRequest<VC>) throws where
        VC: HMCDVersionableType
    {
        let original = try request.originalVC()
        let edited = try request.editedVC()
        
        switch request.conflictStrategy() {
        case .error:
            throw VersionConflict.Exception.builder()
                .with(existingVersion: original.currentVersion())
                .with(conflictVersion: edited.currentVersion())
                .build()
            
        case .overwrite:
            try attempVersionUpdateUnsafely(context, request)
            
        case .takePreferable:
            if try edited.hasPreferableVersion(over: original) {
                try attempVersionUpdateUnsafely(context, request)
            }
        }
    }
    
    /// Perform version update and delete existing object in the DB. This step
    /// assumes that version comparison has been carried out and all conflicts
    /// have been resolved.
    ///
    /// This operation is not thread-safe.
    ///
    /// - Parameters:
    ///   - context: A NSManagedObjectContext instance.
    ///   - request: A HMVersionUpdateRequest instance.
    /// - Throws: Exception if the operation fails.
    func attempVersionUpdateUnsafely<VC>(
        _ context: NSManagedObjectContext,
        _ request: HMVersionUpdateRequest<VC>) throws where
        VC: HMCDVersionableType
    {
        let original = try request.originalVC()
        let edited = try request.editedVC()
        let newVersion = edited.oneVersionHigher()
        
        // The original object should be managed by the parameter context.
        // We update the original object by mutating it - under other circumstances,
        // this is not recommended.
        try original.update(from: edited)
        try original.updateVersion(newVersion)
    }
    
    /// Update some object with version bump. Resolve any conflict if necessary.
    /// This operation is not thread-safe.
    ///
    /// - Parameters:
    ///   - context: A NSManagedObjectContext instance.
    ///   - request: A HMVersionUpdateRequest instance.
    /// - Throws: Exception if the operation fails.
    func updateVersionUnsafely<VC>(
        _ context: NSManagedObjectContext,
        _ request: HMVersionUpdateRequest<VC>) throws where
        VC: HMCDVersionableType
    {
        let originalVersion = try request.originalVC().currentVersion()
        let editedVersion = try request.editedVC().currentVersion()
        
        if originalVersion == editedVersion {
            try attempVersionUpdateUnsafely(context, request)
        } else {
            try resolveVersionConflictUnsafely(context, request)
        }
    }
}

public extension HMCDManager {
    
    /// Perform update on the identifiables, insert them into the specified
    /// context and and get the results back.
    ///
    /// - Parameters:
    ///   - context: A NSManagedObjectContext instance.
    ///   - entityName: A String value representing the entity's name.
    ///   - requests: A Sequence of HMVersionUpdateRequest.
    /// - Throws: Exception if the operation fails.
    func convert<VC,S>(_ context: NSManagedObjectContext,
                       _ entityName: String,
                       _ requests: S) throws -> [HMResult] where
        VC: HMCDConvertibleType,
        VC: HMCDIdentifiableType,
        VC: HMCDVersionableType,
        S: Sequence,
        S.Iterator.Element == HMVersionUpdateRequest<VC>
    {
        // It's ok for these requests not to have the original object. We will
        // get them right below.
        let identifiables = requests.flatMap({try? $0.editedVC()})
        let originals = try self.blockingRefetch(context, entityName, identifiables)
        var results: [HMResult] = []
        
        // We also need an Array of VC to store items that cannot be found in
        // the DB yet.
        var nonExisting: [VC] = []
        
        for item in identifiables {
            if
                let original = originals.first(where: item.identifiable),
                let request = requests.first(where: {($0.ownsEditedVC(item))})?
                    .cloneBuilder()
                    .with(original: original)
                    .with(edited: item)
                    .build()
            {
                let result: HMResult
                
                do {
                    try self.updateVersionUnsafely(context, request)
                    result = HMResult.just(item)
                } catch let e {
                    result = HMResult.builder()
                        .with(object: item)
                        .with(error: e)
                        .build()
                }
                
                results.append(result)
            } else {
                nonExisting.append(item)
            }
        }
        
        // For items that do not exist in the DB yet, simply save them. Since
        // these objects are convertible, we can reconstruct them as NSManagedObject
        // instances and insert into the specified context.
        results.append(contentsOf: convert(context, nonExisting))
        
        return results
    }
    
    /// Update a Sequence of versioned objects and save to memory. It is better
    /// not to call this method on too many objects, because context.save()
    /// will be called just as many times.
    ///
    /// - Parameters:
    ///   - context: A NSManagedObjectContext instance.
    ///   - entityName: A String value representing the entity's name.
    ///   - requests: A Sequence of HMVersionUpdateRequest.
    ///   - obs: An ObserverType instance.
    /// - Throws: Exception if the operation fails.
    func updateVersion<VC,S,O>(_ context: NSManagedObjectContext,
                               _ entityName: String,
                               _ requests: S,
                               _ obs: O) where
        VC: HMCDConvertibleType,
        VC: HMCDIdentifiableType,
        VC: HMCDVersionableType,
        S: Sequence,
        S.Iterator.Element == HMVersionUpdateRequest<VC>,
        O: ObserverType,
        O.E == [HMResult]
    {
        performOnContextThread(mainContext) {
            do {
                let results = try self.convert(context, entityName, requests)
                try self.saveUnsafely(context)
                obs.onNext(results)
                obs.onCompleted()
            } catch let e {
                obs.onError(e)
            }
        }
    }
}

extension Reactive where Base: HMCDManager {
    
    /// Update a Sequence of versioned objects and save to memory.
    ///
    /// - Parameters:
    ///   - context: A NSManagedObjectContext instance.
    ///   - entityName: A String value representing the entity's name.
    ///   - requests: A Sequence of HMVersionUpdateRequest.
    /// - Return: An Observable instance.
    /// - Throws: Exception if the operation fails.
    public func updateVersion<VC,S>(_ context: NSManagedObjectContext,
                                    _ entityName: String,
                                    _ requests: S)
        -> Observable<[HMResult]> where
        VC: HMCDConvertibleType,
        VC: HMCDIdentifiableType,
        VC: HMCDVersionableType,
        S: Sequence,
        S.Iterator.Element == HMVersionUpdateRequest<VC>
    {
        return Observable<[HMResult]>.create({
            self.base.updateVersion(context, entityName, requests, $0)
            return Disposables.create()
        })
    }
    
    /// Update a Sequence of versioned objects and save to memory with a default
    /// context.
    ///
    /// - Parameters:
    ///   - entityName: A String value representing the entity's name.
    ///   - requests: A Sequence of HMVersionUpdateRequest.
    ///   - strategyFn: A strategy producer.
    /// - Return: An Observable instance.
    /// - Throws: Exception if the operation fails.
    public func updateVersion<VC,S>(_ entityName: String, _ requests: S)
        -> Observable<[HMResult]> where
        VC: HMCDConvertibleType,
        VC: HMCDIdentifiableType,
        VC: HMCDVersionableType,
        S: Sequence,
        S.Iterator.Element == HMVersionUpdateRequest<VC>
    {
        let context = base.disposableObjectContext()
        return updateVersion(context, entityName, requests)
    }
}
