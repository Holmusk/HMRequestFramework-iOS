//
//  HMCDManager+Reset+Rx.swift
//  HMRequestFramework
//
//  Created by Hai Pham on 22/8/17.
//  Copyright © 2017 Holmusk. All rights reserved.
//

import CoreData
import RxSwift

public extension HMCDManager {
    
    /// Reset stores using the store coordinator. This operation is not thread-safe.
    ///
    /// - Throws: Exception if the reset fails.
    func resetStoresUnsafely() throws {
        let coordinator = self.coordinator
        let stores = coordinator.persistentStores
        
        if stores.isNotEmpty {
            try stores.forEach(coordinator.remove)
            try applyStoreSettings(coordinator, self.settings)
        }
    }
    
    /// Reset some context to its initial state. This operation is not thread-safe.
    ///
    /// - Parameter context: A NSManagedObjectContext instance.
    func resetContextUnsafely(_ context: NSManagedObjectContext) {
        context.reset()
    }
    
    /// Reset some context to its initial state and observe the process.
    ///
    /// - Parameters:
    ///   - context: A NSManagedObjectContext instance.
    ///   - obs: An ObserverType instance.
    func resetContext<O>(_ context: NSManagedObjectContext, _ obs: O) where
        O: ObserverType, O.E == Void
    {
        performOnContextThread(context) {
            self.resetContextUnsafely(context)
            obs.onNext(())
            obs.onCompleted()
        }
    }
    
    /// Reset stores and observer the process.
    ///
    /// - Parameter obs: An ObserverType instance.
    func resetStores<O>(_ obs: O) where O: ObserverType, O.E == Void {
        coordinator.perform({
            do {
                try self.resetStoresUnsafely()
                obs.onNext(())
                obs.onCompleted()
            } catch let e {
                obs.onError(e)
            }
        })
    }
}

extension Reactive where Base == HMCDManager {
    
    /// Reset some context reactively.
    ///
    /// - Parameter context: A NSManagedObjectContext instance.
    /// - Returns: An Observable instance.
    func resetContext(_ context: NSManagedObjectContext) -> Observable<Void> {
        return Observable<Void>.create({
            self.base.resetContext(context, $0)
            return Disposables.create()
        })
    }
    
    /// Reset stores reactively.
    ///
    /// - Returns: An Observable instance.
    func resetStores() -> Observable<Void> {
        return Observable<Void>.create({
            self.base.resetStores($0)
            return Disposables.create()
        })
    }
    
    /// Reset the entire stack by resetting contexts and wipe the DB.
    ///
    /// - Returns: An Observable instance.
    public func resetStack() -> Observable<Void> {
        let base = self.base
        
        return Observable
            .concat(
                resetContext(base.mainObjectContext()),
                resetContext(base.privateObjectContext()),
                
                // Store reset must not happen on the main thread.
                resetStores().subscribeOn(qos: .userInitiated)
            )
            .reduce((), accumulator: {_ in ()})
            .observeOn(MainScheduler.instance)
    }
}
