//
//  CoreDataRequestTest.swift
//  HMRequestFrameworkTests
//
//  Created by Hai Pham on 8/9/17.
//  Copyright © 2017 Holmusk. All rights reserved.
//

import CoreData
import RxSwift
import RxBlocking
import RxTest
import SwiftUtilities
import SwiftUtilitiesTests
import XCTest
@testable import HMRequestFramework

public final class CoreDataRequestTest: CoreDataRootTest {
    public typealias Req = HMCDRequestProcessor.Req
    let generatorError = "Generator error!"
    let processorError = "Processor error!"
    var rqMiddlewareManager: HMMiddlewareManager<Req>!
    var cdProcessor: HMCDRequestProcessor!
    var dbProcessor: DBRequestProcessor!
    
    override public func setUp() {
        super.setUp()
        rqMiddlewareManager = HMMiddlewareManager<Req>.builder().build()
        
        cdProcessor = HMCDRequestProcessor.builder()
            .with(manager: manager)
            .with(rqMiddlewareManager: rqMiddlewareManager)
            .build()
        
        dbProcessor = DBRequestProcessor(processor: cdProcessor)
    }
    
    /// This test represents the upper layer (API user). We are trying to prove
    /// that this upper layer knows nothing about the specific database
    /// implementation (e.g. CoreData or Realm).
    ///
    /// All specific database references are restricted to request generators
    /// and result processors.
    public func test_databaseRequestProcessor_shouldNotLeakContext() {
        /// Setup
        let observer = scheduler.createObserver(Try<Any>.self)
        let expect = expectation(description: "Should have completed")
        let dbProcessor = self.dbProcessor!.processor
        let generator = errorDBRgn()
        let processor = errorDBRps()

        /// When
        dbProcessor.process(dummy, generator, processor)
            .map({$0.map({$0 as Any})})
            .flatMap({dbProcessor.process($0, generator, processor)})
            .map({$0.map({$0 as Any})})
            .flatMap({dbProcessor.process($0, generator, processor)})
            .map({$0.map({$0 as Any})})
            .flatMap({dbProcessor.process($0, generator, processor)})
            .map({$0.map({$0 as Any})})
            .doOnDispose(expect.fulfill)
            .subscribe(observer)
            .disposed(by: disposeBag)

        waitForExpectations(timeout: timeout, handler: nil)

        /// Then
        let nextElements = observer.nextElements()
        XCTAssertEqual(nextElements.count, 1)

        let first = nextElements.first!
        XCTAssertTrue(first.isFailure)
        XCTAssertEqual(first.error!.localizedDescription, generatorError)
    }
    
    public func test_insertAndDeleteRandomDummies_shouldWork() {
        /// Setup
        let observer = scheduler.createObserver(Dummy1.self)
        let expect = expectation(description: "Should have completed")
        let cdProcessor = self.cdProcessor!
        let manager = self.manager!
        let context = manager.disposableObjectContext()
        let dummyCount = self.dummyCount
        let pureObjects = (0..<dummyCount).map({_ in Dummy1()})
        let cdObjects = try! manager.constructUnsafely(context, pureObjects)
        let insertGn = dummy1InsertRgn(cdObjects)
        let insertPs = dummy1InsertRps()
        let persistGn = dummyPersistRgn()
        let deleteGn = dummyMemoryDeleteRgn(cdObjects)
        let fetchGn = dummy1FetchRgn()

        /// When
        // Save the changes in the disposable context.
        cdProcessor.process(dummy, insertGn, insertPs)
            .map({$0.map({$0 as Any})})

            // Persist changes to DB.
            .flatMap({cdProcessor.processVoid($0, persistGn)})
            .map({$0.map({$0 as Any})})

            // Fetch to verify that data have been persisted.
            .flatMap({cdProcessor.process($0, fetchGn, Dummy1.self)})
            .map({try $0.getOrThrow()})
            .doOnNext({XCTAssertEqual($0.count, dummyCount)})
            .doOnNext({XCTAssertTrue(pureObjects.all($0.contains))})
            .map({$0 as Any}).map(Try.success)

            // Delete data from memory, but do not persist to DB yet.
            .flatMap({cdProcessor.processVoid($0, deleteGn)})
            .map({$0.map({$0 as Any})})

            // Persist changes to DB.
            .flatMap({cdProcessor.processVoid($0, persistGn)})
            .map({$0.map({$0 as Any})})

            // Fetch to verify that the data have been deleted.
            .flatMap({cdProcessor.process($0, fetchGn, Dummy1.self)})
            .map({try $0.getOrThrow()})
            .flatMap({Observable.from($0)})
            .doOnDispose(expect.fulfill)
            .subscribe(observer)
            .disposed(by: disposeBag)

        waitForExpectations(timeout: timeout, handler: nil)

        /// Then
        let nextElements = observer.nextElements()
        XCTAssertEqual(nextElements.count, 0)
    }
    
    public func test_batchDelete_shouldWork() {
        if case .InMemory = storeType! {
            return
        }

        /// Setup
        let observer = scheduler.createObserver(Dummy1.self)
        let expect = expectation(description: "Should have completed")
        let cdProcessor = self.cdProcessor!
        let manager = self.manager!
        let context = manager.disposableObjectContext()
        let dummyCount = self.dummyCount
        let pureObjects = (0..<dummyCount).map({_ in Dummy1()})
        let cdObjects = try! manager.constructUnsafely(context, pureObjects)
        let insertGn = dummy1InsertRgn(cdObjects)
        let insertPs = dummy1InsertRps()
        let persistGn = dummyPersistRgn()
        let deleteGn = dummy1BatchDeleteRgn()
        let fetchGn = dummy1FetchRgn()

        /// When
        // Save the changes in the disposable context.
        cdProcessor.process(dummy, insertGn, insertPs)
            .map({$0.map({$0 as Any})})

            // Persist changes to DB.
            .flatMap({cdProcessor.processVoid($0, persistGn)})
            .map({$0.map({$0 as Any})})

            // Fetch to verify that data have been persisted.
            .flatMap({cdProcessor.process($0, fetchGn, Dummy1.self)})
            .map({try $0.getOrThrow()})
            .doOnNext({XCTAssertEqual($0.count, dummyCount)})
            .doOnNext({XCTAssertTrue(pureObjects.all($0.contains))})
            .map({$0 as Any}).map(Try.success)

            // Delete data from DB. Make sure this is a SQLite store though.
            .flatMap({cdProcessor.processVoid($0, deleteGn)})
            .map({$0.map({$0 as Any})})

            // Persist changes to DB.
            .flatMap({cdProcessor.processVoid($0, persistGn)})
            .map({$0.map({$0 as Any})})

            // Fetch to verify that the data have been deleted.
            .flatMap({cdProcessor.process($0, fetchGn, Dummy1.self)})
            .map({try $0.getOrThrow()})
            .flatMap({Observable.from($0)})
            .doOnDispose(expect.fulfill)
            .subscribe(observer)
            .disposed(by: disposeBag)

        waitForExpectations(timeout: timeout, handler: nil)

        /// Then
        let nextElements = observer.nextElements()
        XCTAssertEqual(nextElements.count, 0)
    }
    
    public func test_coreDataUpsert_shouldWork() {
        /// Setup
        let observer = scheduler.createObserver(Dummy1.self)
        let expect = expectation(description: "Should have completed")
        let manager = self.manager!
        let dbProcessor = self.dbProcessor!.processor
        let context = manager.disposableObjectContext()
        let times1 = 1000
        let times2 = 2000
        let pureObjects1 = (0..<times1).map({_ in Dummy1()})
        let pureObjects2 = (0..<times2).map({_ in Dummy1()})

        // Since we are using overwrite, we expect the upsert to still succeed.
        let pureObjects3 = (0..<times1).map({(index) -> Dummy1 in
            let dummy = Dummy1()
            let previous = pureObjects1[index]
            dummy.id = previous.id
            dummy.version = (previous.version!.intValue + 1) as NSNumber
            return dummy
        })

        let pureObjects23 = [pureObjects2, pureObjects3].flatMap({$0})
        let cdObjects1 = try! manager.constructUnsafely(context, pureObjects1)
        let cdObjects23 = try! manager.constructUnsafely(context, pureObjects23)
        let insertGn = dummy1InsertRgn(cdObjects1)
        let insertPs = dummy1UpsertRps()
        let persistGn = dummyPersistRgn()
        let upsertGn = dummy1UpsertRgn(cdObjects23, .overwrite)
        let upsertPs = dummy1UpsertRps()
        let fetchGn = dummy1FetchRgn()

        /// When
        // Insert the first set of data.
        dbProcessor.process(dummy, insertGn, insertPs)
            .map({$0.map({$0 as Any})})

            // Persist changes to DB.
            .flatMap({dbProcessor.processVoid($0, persistGn)})
            .map({$0.map({$0 as Any})})

            .flatMap({dbProcessor.process($0, fetchGn, Dummy1.self)})
            .map({try $0.getOrThrow()})
            .doOnNext({XCTAssertTrue(pureObjects1.all($0.contains))})
            .doOnNext({XCTAssertEqual($0.count, times1)})
            .cast(to: Any.self).map(Try.success)

            // Upsert the second set of data. This set of data contains some
            // data with the same ids as the first set of data.
            .flatMap({dbProcessor.process($0, upsertGn, upsertPs)})
            .map({$0.map({$0 as Any})})

            // Persist changes to DB.
            .flatMap({dbProcessor.processVoid($0, persistGn)})
            .map({$0.map({$0 as Any})})

            // Fetch all data to check that the upsert was successful.
            .flatMap({dbProcessor.process($0, fetchGn, Dummy1.self)})
            .map({try $0.getOrThrow()})
            .flatMap({Observable.from($0)})
            .doOnDispose(expect.fulfill)
            .subscribe(observer)
            .disposed(by: disposeBag)

        waitForExpectations(timeout: timeout, handler: nil)

        /// Then
        let nextElements = observer.nextElements()
        XCTAssertEqual(nextElements.count, pureObjects23.count)
        XCTAssertTrue(pureObjects23.all(nextElements.contains))
        XCTAssertFalse(pureObjects1.any(nextElements.contains))
    }
    
    public func test_upsertVersionableWithErrorStrategy_shouldNotOverwrite() {
        /// Setup
        let observer = scheduler.createObserver(Dummy1.self)
        let expect = expectation(description: "Should have completed")
        let manager = self.manager!
        let dbProcessor = self.dbProcessor!.processor
        let context = manager.disposableObjectContext()
        let times = 1000
        let pureObjects1 = (0..<times).map({_ in Dummy1()})

        // Since we are using error, we expect the upsert to fail.
        let pureObjects2 = (0..<times).map({(index) -> Dummy1 in
            let dummy = Dummy1()
            let previous = pureObjects1[index]
            dummy.id = previous.id
            dummy.version = (previous.version!.intValue + 1) as NSNumber
            return dummy
        })

        let cdObjects1 = try! manager.constructUnsafely(context, pureObjects1)
        let cdObjects2 = try! manager.constructUnsafely(context, pureObjects2)
        let insertGn = dummy1InsertRgn(cdObjects1)
        let insertPs = dummy1UpsertRps()
        let persistGn = dummyPersistRgn()
        let upsertGn = dummy1UpsertRgn(cdObjects2, .error)
        let upsertPs = dummy1UpsertRps()
        let fetchGn = dummy1FetchRgn()

        /// When
        // Insert the first set of data.
        dbProcessor.process(dummy, insertGn, insertPs)
            .map({$0.map({$0 as Any})})

            // Persist changes to DB.
            .flatMap({dbProcessor.processVoid($0, persistGn)})
            .map({$0.map({$0 as Any})})

            .flatMap({dbProcessor.process($0, fetchGn, Dummy1.self)})
            .map({try $0.getOrThrow()})
            .doOnNext({XCTAssertTrue(pureObjects1.all($0.contains))})
            .doOnNext({XCTAssertEqual($0.count, times)})
            .cast(to: Any.self).map(Try.success)

            // Upsert the second set of data.
            .flatMap({dbProcessor.process($0, upsertGn, upsertPs)})
            .map({$0.map({$0 as Any})})

            // Persist changes to DB.
            .flatMap({dbProcessor.processVoid($0, persistGn)})
            .map({$0.map({$0 as Any})})

            // Fetch all data to check that the upsert failed.
            .flatMap({dbProcessor.process($0, fetchGn, Dummy1.self)})
            .map({try $0.getOrThrow()})
            .flatMap({Observable.from($0)})
            .doOnDispose(expect.fulfill)
            .subscribe(observer)
            .disposed(by: disposeBag)

        waitForExpectations(timeout: timeout, handler: nil)

        /// Then
        let nextElements = observer.nextElements()

        // Only the old data exists in the DB. The updated versionables are not
        // persisted due to error conflict strategy.
        XCTAssertEqual(nextElements.count, times)
        XCTAssertTrue(pureObjects1.all(nextElements.contains))
        XCTAssertFalse(pureObjects2.any(nextElements.contains))
    }
    
    public func test_insertConvertibleData_shouldWork() {
        /// Setup
        let observer = scheduler.createObserver(Dummy1.self)
        let expect = expectation(description: "Should have completed")
        let dbProcessor = self.dbProcessor!.processor
        let manager = self.manager!
        let context = manager.disposableObjectContext()
        let dummyCount = self.dummyCount
        let pureObjects = (0..<dummyCount).map({_ in Dummy1()})
        let cdObjects = try! manager.constructUnsafely(context, pureObjects)

        let insertGn = dummy1InsertRgn(cdObjects)
        let insertPs = dummy1InsertRps()
        let persistGn = dummyPersistRgn()
        let fetchGn = dummy1FetchRgn()

        /// When
        dbProcessor.process(dummy, insertGn, insertPs)
            .map({$0.map({$0 as Any})})
            .flatMap({dbProcessor.processVoid($0, persistGn)})
            .map({$0.map({$0 as Any})})
            .flatMap({dbProcessor.process($0, fetchGn, Dummy1.self)})
            .map({try $0.getOrThrow()})
            .flatMap({Observable.from($0)})
            .doOnDispose(expect.fulfill)
            .subscribe(observer)
            .disposed(by: disposeBag)

        waitForExpectations(timeout: timeout, handler: nil)

        /// Then
        let nextElements = observer.nextElements()
        XCTAssertEqual(nextElements.count, pureObjects.count)
        XCTAssertTrue(pureObjects.all(nextElements.contains))
    }
    
    public func test_cdNonTypedRequestObject_shouldThrowErrorsIfNecessary() {
        var currentCheck = 0
        let processor = cdProcessor!
        
        let checkError: (Req, Bool) -> Req = {
            currentCheck += 1
            print("Checking request \(currentCheck)")
            
            let request = $0.0
            
            do {
                _ = try processor.execute(request).toBlocking().first()
            } catch let e {
                print(e)
                XCTAssertTrue($0.1)
            }
            
            return request
        }
        
        /// 1
        let request1 = checkError(Req.builder().build(), true)
        
        /// 2
        let request2 = checkError(request1.cloneBuilder()
            .with(entityName: "E1")
            .build(), true)
        
        /// 3
        let request3 = checkError(request2.cloneBuilder()
            .with(operation: .persistLocally)
            .build(), true)
        
        /// End
        _ = request3
    }
}

extension CoreDataRequestTest {
    func dummy1InsertRequest(_ data: [Dummy1.CDClass]) -> Req {
        return HMCDRequest.builder()
            .with(operation: .saveData)
            .with(insertedData: data)
            .build()
    }
    
    func dummy1InsertRgn(_ data: [Dummy1.CDClass]) -> HMAnyRequestGenerator<Req> {
        return HMRequestGenerators.forceGenerateFn(dummy1InsertRequest(data))
    }
    
    func dummy1InsertRps() -> HMResultProcessor<HMCDResult,Void> {
        return {Observable.just($0).map(toVoid).map(Try.success)}
    }
    
    func dummy1UpsertRequest(_ data: [Dummy1.CDClass],
                             _ strategy: VersionConflict.Strategy) -> Req {
        return HMCDRequest.builder()
            .with(operation: .upsert)
            .with(poType: Dummy1.self)
            .with(upsertedData: data)
            .with(vcStrategy: strategy)
            .build()
    }
    
    func dummy1UpsertRgn(_ data: [Dummy1.CDClass],
                         _ strategy: VersionConflict.Strategy)
        -> HMAnyRequestGenerator<Req>
    {
        let request = dummy1UpsertRequest(data, strategy)
        return HMRequestGenerators.forceGenerateFn(request, Any.self)
    }
    
    func dummy1UpsertRps() -> HMResultProcessor<HMCDResult,Void> {
        return {Observable.just($0).map(toVoid).map(Try.success)}
    }

    func dummy1FetchRgn() -> HMAnyRequestGenerator<Req> {
        return HMRequestGenerators.forceGenerateFn(dummy1FetchRequest())
    }
    
    func dumm1BatchDeleteRequest() -> Req {
        return Req.builder()
            .with(poType: Dummy1.self)
            .with(predicate: NSPredicate(value: true))
            .build()
    }
    
    func dummy1BatchDeleteRgn() -> HMAnyRequestGenerator<Req> {
        return HMRequestGenerators.forceGenerateFn(dumm1BatchDeleteRequest(), Any.self)
    }

    func dummyPersistRequest() -> Req {
        return Req.builder().with(operation: .persistLocally).build()
    }

    func dummyPersistRgn() -> HMAnyRequestGenerator<Req> {
        return HMRequestGenerators.forceGenerateFn(dummyPersistRequest())
    }

    func dummyMemoryDeleteRequest(_ data: [NSManagedObject]) -> Req {
        return Req.builder()
            .with(operation: .delete)
            .with(deletedData: data)
            .build()
    }

    func dummyMemoryDeleteRgn(_ data: [NSManagedObject]) -> HMAnyRequestGenerator<Req> {
        return HMRequestGenerators.forceGenerateFn(dummyMemoryDeleteRequest(data))
    }
}

extension CoreDataRequestTest {
    func errorDBRgn() -> HMAnyRequestGenerator<Req> {
        return {_ in throw Exception(self.generatorError)}
    }

    func errorDBRps() -> HMResultProcessor<NSManagedObject,Any> {
        return {_ in throw Exception(self.processorError)}
    }
}
