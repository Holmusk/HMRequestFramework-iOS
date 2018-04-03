//
//  CoreDataObjectTest.swift
//  HMRequestFrameworkTests
//
//  Created by Hai Pham on 11/8/17.
//  Copyright © 2017 Holmusk. All rights reserved.
//

import CoreData
import XCTest
@testable import HMRequestFramework

public final class CoreDataObjectTest: CoreDataRootTest {
    public func test_convertCDObjectsToDict_shouldWork() {
        /// Setup
        let manager = self.manager!
        let context = manager.disposableObjectContext()
        let dummyCount = self.dummyCount!
        let dummies = (0..<dummyCount).map({_ in Dummy1()})
        let cdObjects = dummies.map({try! manager.constructUnsafely(context, $0)})
        
        for (dummy, cdObject) in zip(dummies, cdObjects) {
            /// When
            let properties = cdObject.updateDictionary()
            let reconstructed = Dummy1.builder().with(json: properties).build()
            
            /// Then
            XCTAssertEqual(dummy, reconstructed)
        }
    }
    
    public func test_updateCDObjectsWithDict_shouldWork() {
        /// Setup
        let manager = self.manager!
        let context = manager.disposableObjectContext()
        let dummyCount = self.dummyCount!
        let pureObjects1 = (0..<dummyCount).map({_ in Dummy1()})
        let pureObjects2 = (0..<dummyCount).map({_ in Dummy1()})
        let cdObjects1 = try! manager.constructUnsafely(context, pureObjects1)
        let cdObjects2 = try! manager.constructUnsafely(context, pureObjects2)
        
        /// When
        cdObjects2.enumerated().forEach({
            try! $0.element.update(from: cdObjects1[$0.offset])
        })
        
        /// Then
        let reconverted2 = cdObjects2.map({try! $0.asPureObject()})
        XCTAssertTrue(pureObjects1.all(reconverted2.contains))
        XCTAssertFalse(pureObjects2.any(reconverted2.contains))
    }
    
    public func test_convertCoreDataToPureObjectAndBack_shouldWork() {
        /// Setup
        let manager = self.manager!
        let context = manager.disposableObjectContext()
        let times = 1000
        let dummies = (0..<times).map({_ in Dummy1()})
        
        /// When
      let cdObjects = dummies.compactMap({try? $0.asManagedObject(context)})
      let newDummies = cdObjects.compactMap({$0 as? Dummy1.CDClass}).map({try! $0.asPureObject()})
        
        /// Then
        XCTAssertEqual(newDummies.count, dummies.count)
        XCTAssertTrue(dummies.all(newDummies.contains))
    }
}
