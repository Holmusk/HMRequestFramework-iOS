//
//  CoreDataFRCTest.swift
//  HMRequestFrameworkTests
//
//  Created by Hai Pham on 8/23/17.
//  Copyright © 2017 Holmusk. All rights reserved.
//

import CoreData
import RxSwift
import RxTest
import XCTest
import SwiftFP
import SwiftUtilities
@testable import HMRequestFramework

public final class CoreDataFRCTest: CoreDataRootTest {
  var iterationCount: Int!

  deinit {
    print("Deinit \(self)")
  }

  override public func setUp() {
    super.setUp()
    iterationCount = 5
    dummyCount = 1000
    dbWait = 0.1
  }

  public func test_sectionWithObjectLimit_shouldWork() {
    /// Setup
    let sectionCount = 1000
    let times = 1

    for _ in 0..<times {
      /// Setup
      let sections = (0..<sectionCount).map({_ -> HMCDSection<Void> in
        let objectCount = Int.random(100, 1000)
        let objects = (0..<objectCount).map({_ in ()})

        return HMCDSection<Void>(indexTitle: "",
                                 name: "",
                                 numberOfObjects: objectCount,
                                 objects: objects)
      })

      let limit = Int.random(100, 1000)

      /// When
      let slicedSections = HMCDSections.sectionsWithLimit(sections, limit)

      /// Then
      XCTAssertEqual(slicedSections.flatMap({$0.objects}).count, limit)
    }

    /// Then
  }

  public func test_streamDBInsertsWithProcessor_shouldWork() {
    /// Setup
    let observer = scheduler.createObserver(Any.self)
    let frcObserver = scheduler.createObserver(Any.self)
    let expect = expectation(description: "Should have completed")
    let frcExpect = expectation(description: "Should have completed")
    let processor = self.dbProcessor!
    let iterationCount = self.iterationCount!
    let dummyCount = self.dummyCount!
    var allDummies: [Dummy1] = []

    var callCount = 0
    var willLoadCount = 0
    var didLoadCount = 0
    var willChangeCount = 0
    var didChangeCount = 0
    var insertCount = 0

    let terminateSbj = PublishSubject<Void>()

    /// When
    processor
      .streamDBEvents(Dummy1.self, .background)
      .doOnNext({_ in callCount += 1})
      .map({try $0.getOrThrow()})
      .doOnNext({
        switch $0 {
        case .didLoad: didLoadCount += 1
        case .willLoad: willLoadCount += 1
        case .didChange: didChangeCount += 1
        case .willChange: willChangeCount += 1
        case .insert: insertCount += 1
        default: break
        }
      })
      .doOnNext(self.validateDidLoad)
      .doOnNext(self.validateInsert)
      .cast(to: Any.self)
      .takeUntil(terminateSbj)
      .doOnDispose(frcExpect.fulfill)
      .subscribe(frcObserver)
      .disposed(by: disposeBag)

    insertNewObjects({allDummies.append(contentsOf: $0)})
      .doOnDispose(expect.fulfill)
      .subscribe(observer)
      .disposed(by: disposeBag)

    background(.background, closure: {
      while didChangeCount < iterationCount {}
      terminateSbj.onNext(())
    })

    waitForExpectations(timeout: timeout, handler: nil)

    /// Then
    XCTAssertTrue(callCount >= iterationCount)

    // Initialize event adds 1 to the count.
    XCTAssertEqual(didLoadCount, iterationCount + 1)
    XCTAssertEqual(willLoadCount, iterationCount + 1)
    XCTAssertEqual(didChangeCount, iterationCount)
    XCTAssertEqual(willChangeCount, iterationCount)
    XCTAssertEqual(insertCount, iterationCount * dummyCount)

    XCTAssertEqual(callCount, 0
      + didLoadCount
      + willLoadCount
      + didChangeCount
      + willChangeCount
      + insertCount
    )
  }

  // For this test, we are introducing section events as well, so we need
  // to take care when comparing event counts.
  public func test_streamDBUpdateAndDeleteEvents_shouldWork() {
    /// Setup
    let observer = scheduler.createObserver(Any.self)
    let expect = expectation(description: "Should have completed")
    let frcExpect = expectation(description: "Should have completed")

    let frcRequest = dummy1FetchRequest()
      .cloneBuilder()
      .with(frcSectionName: "id")
      .build()

    let iterationCount = self.iterationCount!
    let dummyCount = self.dummyCount!
    var originalObjects: [Dummy1] = []

    // The willLoad and didLoad counts will be higher than update count
    // because they apply to inserts and deletes as well.
    var callCount = 0
    var willLoadCount = 0
    var didLoadCount = 0
    var willChangeCount = 0
    var didChangeCount = 0
    var insertCount = 0
    var insertSectionCount = 0
    var updateCount = 0
    var updateSectionCount = 0
    var deleteCount = 0
    var deleteSectionCount = 0

    let terminateSbj = PublishSubject<Void>()

    /// When
    manager.rx.startDBStream(frcRequest, Dummy1.self, .background)
      .doOnNext({_ in callCount += 1})
      .doOnNext({
        switch $0 {
        case .willLoad: willLoadCount += 1
        case .didLoad: didLoadCount += 1
        case .willChange: willChangeCount += 1
        case .didChange: didChangeCount += 1
        case .insert: insertCount += 1
        case .insertSection: insertSectionCount += 1
        case .update: updateCount += 1
        case .updateSection: updateSectionCount += 1
        case .delete: deleteCount += 1
        case .deleteSection: deleteSectionCount += 1
        default: break
        }
      })
      .doOnNext({self.validateDidLoad($0)})
      .doOnNext({self.validateInsert($0)})
      .doOnNext(self.validateInsertSection)
      .doOnNext(self.validateUpdate)
      .doOnNext(self.validateUpdateSection)
      .doOnNext({self.validateDelete($0)})
      .doOnNext(self.validateDeleteSection)
      .cast(to: Any.self)
      .takeUntil(terminateSbj)
      .doOnDispose(frcExpect.fulfill)
      .subscribe(observer)
      .disposed(by: disposeBag)

    self.upsertAndDelete({originalObjects.append(contentsOf: $0)},
                         {_ in}, {})
      .doOnDispose(expect.fulfill)
      .subscribe(observer)
      .disposed(by: disposeBag)

    background(.background, closure: {
      while didChangeCount < iterationCount + 2 {}
      terminateSbj.onNext(())
    })

    waitForExpectations(timeout: timeout, handler: nil)

    /// Then
    XCTAssertTrue(callCount > iterationCount)

    // Initialize event adds 1 to the count, and so did delete event. That's
    // why we add 2 to the iterationCount.
    XCTAssertEqual(willChangeCount, iterationCount + 2)
    XCTAssertEqual(didChangeCount, iterationCount + 2)
    XCTAssertEqual(willLoadCount, iterationCount + 3)
    XCTAssertEqual(didLoadCount, iterationCount + 3)
    XCTAssertEqual(insertCount, dummyCount)
    XCTAssertEqual(insertSectionCount, dummyCount)
    XCTAssertEqual(updateCount, iterationCount * dummyCount)
    XCTAssertEqual(updateSectionCount, 0)
    XCTAssertEqual(deleteCount, dummyCount)
    XCTAssertEqual(deleteSectionCount, dummyCount)

    XCTAssertEqual(callCount, 0
      + willLoadCount
      + didLoadCount
      + willChangeCount
      + didChangeCount
      + insertCount
      + insertSectionCount
      + updateCount
      + updateSectionCount
      + deleteCount
      + deleteSectionCount
    )
  }

  public func test_streamDBEventsWithPagination_shouldWork(_ mode: HMCDPaginationMode) {
    /// Setup
    let observer = scheduler.createObserver(Dummy1.self)
    let streamObserver = scheduler.createObserver([Dummy1].self)
    let expect = expectation(description: "Should have completed")
    let disposeBag = self.disposeBag!
    let dummyCount = self.dummyCount!
    let fetchLimit: UInt = 50
    let pureObjects = (0..<dummyCount).map({_ in Dummy1()})
    let dbProcessor = self.dbProcessor!
    let qos: DispatchQoS.QoSClass = .background

    let fetchOffset: UInt = 0
    let pageLoadTimes = dummyCount / Int(fetchLimit)

    dbProcessor.saveToMemory(Try.success(pureObjects), qos)
      .flatMap({dbProcessor.persistToDB($0, qos)})
      .flatMap({dbProcessor.fetchAllDataFromDB($0, Dummy1.self, qos)})
      .map({try $0.getOrThrow()})
      .flattenSequence()
      .doOnDispose(expect.fulfill)
      .subscribe(observer)
      .disposed(by: disposeBag)

    waitForExpectations(timeout: timeout, handler: nil)
    let nextElements = observer.nextElements()
    XCTAssertEqual(nextElements.count, pureObjects.count)
    XCTAssertTrue(pureObjects.all(nextElements.contains))

    // Here comes the actual streams.
    let sortedPureObjects = pureObjects.sorted(by: {$0.id! < $1.id!})
    let pageSubject = BehaviorSubject<HMCursorDirection>(value: .remain)
    var callCount = 0

    let original = HMCDPagination.builder()
      .with(fetchLimit: fetchLimit)
      .with(fetchOffset: fetchOffset)
      .with(paginationMode: mode)
      .build()

    let terminateSbj = PublishSubject<Void>()

    /// When
    dbProcessor
      .streamPaginatedDBEvents(Dummy1.self, pageSubject, original, qos, {
        Observable.just($0.cloneBuilder()
          .add(ascendingSortWithKey: "id")
          .build())
      })

      // There is only one initialize event, because we are not
      // changing/updating anything in the DB. This event contains
      // only the original, unchanged objects.
      .flatMap(HMCDEvents.didLoadSections)
      .filter({!$0.isEmpty})
      .map({$0.flatMap({$0.objects})})
      .ifEmpty(default: [Dummy1]())
      .doOnNext({_ in callCount += 1})
      .doOnNext({XCTAssertTrue($0.count > 0)})
      .takeUntil(terminateSbj)
      .subscribe(streamObserver)
      .disposed(by: disposeBag)

    var currentPages: [UInt] = []

    for _ in (0...pageLoadTimes) {
      let direction = HMCursorDirection.randomValue()!
      let oldPage = currentPages.last
      let currentPage = UInt(dbProcessor.currentPage(Int(oldPage ?? 1), direction))

      if currentPage != oldPage {
        currentPages.append(currentPage)
      }

      pageSubject.onNext(direction)

      // We need to block for some time because the stream uses flatMapLatest.
      // Everytime we push an event with the subject, the old streams are
      // killed and thus we don't see any result. It's important to have
      // some delay between consecutive triggers for DB events to appear.
      waitOnMainThread(1)
    }

    pageSubject.onCompleted()

    /// Then
    let nextStreamElements = streamObserver.nextElements()
    XCTAssertTrue(nextStreamElements.count > 0)

    // Call count may be different from pageLoadTimes because repeat events
    // are discarded until changed.
    XCTAssertTrue(callCount > 0)

    for (currentPage, objs) in zip(currentPages, nextStreamElements) {
      let count = UInt(objs.count)
      let start: Int
      let end: Int

      switch mode {
      case .fixedPageCount:
        start = Int(fetchOffset + (currentPage - 1) * fetchLimit)
        end = start + Int(fetchLimit)
        XCTAssertEqual(count, fetchLimit)

      case .variablePageCount:
        start = 0
        end = Int(fetchLimit * currentPage)
        print(currentPage)
        XCTAssertEqual(count, fetchLimit * currentPage)
      }

      let slice = sortedPureObjects[start..<end].map({$0})
      XCTAssertEqual(objs, slice)
    }
  }

  public func test_streamDBEventsWithFixedPageCount_shouldWork() {
    test_streamDBEventsWithPagination_shouldWork(.fixedPageCount)
  }

  public func test_streamDBEventsWithVariablePageCount_shouldWork() {
    test_streamDBEventsWithPagination_shouldWork(.variablePageCount)
  }
}

public extension CoreDataFRCTest {
  func validateDidLoad(_ event: HMCDEvent<Dummy1>) {}

  func validateInsert(_ event: HMCDEvent<Dummy1>) {
    if case .insert(let change) = event {
      XCTAssertNil(change.oldIndex)
      XCTAssertNotNil(change.newIndex)
    }
  }

  func validateInsertSection(_ event: HMCDEvent<Dummy1>) {
    if case .insertSection(let change) = event {
      let sectionInfo = change.section
      XCTAssertEqual(sectionInfo.numberOfObjects, 1)
      XCTAssertTrue(sectionInfo.objects.count > 0)
    }
  }

  func validateUpdate(_ event: HMCDEvent<Dummy1>) {
    if case .update(let change) = event {
      XCTAssertNotNil(change.oldIndex)
      XCTAssertNotNil(change.newIndex)
    }
  }

  func validateUpdateSection(_ event: HMCDEvent<Dummy1>) {}

  func validateDelete(_ event: HMCDEvent<Dummy1>,
                      _ asserts: ((Dummy1) -> Bool)...) {
    if case .delete(let change) = event {
      XCTAssertNotNil(change.oldIndex)
      XCTAssertNil(change.newIndex)
      XCTAssertTrue(asserts.map({$0(change.object)}).all({$0}))
    }
  }

  func validateDeleteSection(_ event: HMCDEvent<Dummy1>) {
    if case .deleteSection(let change) = event {
      let sectionInfo = change.section
      XCTAssertEqual(sectionInfo.numberOfObjects, 0)
      XCTAssertEqual(sectionInfo.objects.count, 0)
    }
  }
}

public extension CoreDataFRCTest {
  func insertNewObjects(_ onSave: @escaping ([Dummy1]) -> Void) -> Observable<Any> {
    let manager = self.manager!
    let iterationCount = self.iterationCount!
    let dummyCount = self.dummyCount!

    return Observable
      .range(start: 0, count: iterationCount)
      .flatMap({(_) -> Observable<Void> in
        let context = manager.disposableObjectContext()
        let pureObjects = (0..<dummyCount).map({_ in Dummy1()})

        return Observable
          .concat(
            manager.rx.savePureObjects(context, pureObjects),
            manager.rx.persistLocally()
          )
          .reduce((), accumulator: {(_, _) in ()})
          .doOnNext({onSave(pureObjects)})
          .subscribeOnConcurrent(qos: .background)
      })
      .reduce((), accumulator: {(_, _) in ()})
      .subscribeOnConcurrent(qos: .background)
      .cast(to: Any.self)
  }

  func upsertAndDelete(_ onInsert: @escaping ([Dummy1]) -> Void,
                       _ onUpsert: @escaping ([Dummy1]) -> Void,
                       _ onDelete: @escaping () -> Void) -> Observable<Any> {
    let manager = self.manager!
    let context = manager.disposableObjectContext()
    let deleteContext = manager.disposableObjectContext()
    let iterationCount = self.iterationCount!
    let dummyCount = self.dummyCount!
    let original = (0..<dummyCount).map({_ in Dummy1()})
    let entity = try! Dummy1.CDClass.entityName()

    return manager.rx.savePureObjects(context, original)
      .flatMap({manager.rx.persistLocally()})
      .doOnNext({onInsert(original)})
      .flatMap({_ in Observable.range(start: 0, count: iterationCount)
        .flatMap({(_) -> Observable<Void> in
          let context = manager.disposableObjectContext()
          let upsertCtx = manager.disposableObjectContext()

          let replace = (0..<dummyCount).map({(i) -> Dummy1 in
            let previous = original[i]
            return Dummy1.builder().with(id: previous.id).build()
          })

          return Observable
            .concat(
              manager.rx.construct(context, replace)
                .flatMap({manager.rx.upsert(upsertCtx, entity, $0)})
                .map(toVoid),

              manager.rx.persistLocally()
            )
            .reduce((), accumulator: {(_, _) in ()})
            .doOnNext({onUpsert(replace)})
            .subscribeOnConcurrent(qos: .background)
        })
        .reduce((), accumulator: {(_, _) in ()})
      })
      .flatMap({manager.rx.deleteIdentifiables(deleteContext, entity, original)})
      .flatMap({manager.rx.persistLocally()})
      .subscribeOnConcurrent(qos: .background)
      .doOnNext(onDelete)
      .cast(to: Any.self)
  }
}

public extension CoreDataFRCTest {
  public func test_fetchWithLimit_shouldNotReturnMoreThanLimit(_ limit: Int) {
    print("Testing fetch limit with \(limit) count")

    /// Setup
    let observer = scheduler.createObserver(Try<Void>.self)
    let streamObserver = scheduler.createObserver([Dummy1].self)
    let expect = expectation(description: "Should have completed")
    let disposeBag = self.disposeBag!
    let dbWait = self.dbWait!
    let dbProcessor = self.dbProcessor!
    let dummyCount = 10
    let qos: DispatchQoS.QoSClass = .background

    /// When
    dbProcessor
      .streamDBEvents(Dummy1.self, qos, {
        Observable.just($0.cloneBuilder().with(fetchLimit: limit).build())
      })

      // Skip the initialize (both willLoad and didLoad) events, since
      // they will just return an empty Array anyway.
      .flatMap(HMCDEvents.didLoadSections)
      .filter({!$0.isEmpty})
      .map({$0.flatMap({$0.objects})})
      .skip(1)
      .subscribe(streamObserver)
      .disposed(by: disposeBag)

    Observable.range(start: 0, count: dummyCount)
      .map({_ in Dummy1()})
      .map(Try.success)
      .map({$0.map({[$0]})})
      .concatMap({
        dbProcessor.saveToMemory($0, qos)
          .flatMap({dbProcessor.persistToDB($0, qos)})
          .subscribeOnConcurrent(qos: qos)
          .delay(dbWait, scheduler: ConcurrentDispatchQueueScheduler(qos: qos))
      })
      .doOnDispose(expect.fulfill)
      .subscribe(observer)
      .disposed(by: disposeBag)

    waitForExpectations(timeout: timeout, handler: nil)

    /// Then
    let nextElements = streamObserver.nextElements()
    XCTAssertTrue(nextElements.count > 0)
    XCTAssertTrue(nextElements.all({$0.count <= limit}))
  }

  public func test_fetchWithLimit_shouldNotReturnMoreThanLimit() {
    for i in 1..<10 {
      setUp()
      test_fetchWithLimit_shouldNotReturnMoreThanLimit(i)
      tearDown()
    }
  }
}
