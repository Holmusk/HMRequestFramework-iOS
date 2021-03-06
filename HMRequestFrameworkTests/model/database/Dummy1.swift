//
//  Dummy1.swift
//  HMRequestFramework
//
//  Created by Hai Pham on 7/25/17.
//  Copyright © 2017 Holmusk. All rights reserved.
//

import CoreData
import Differentiator
import SwiftUtilities
@testable import HMRequestFramework

public protocol Dummy1Type {
    var id: String? { get }
    var date: Date? { get }
    var int64: NSNumber? { get }
    var float: NSNumber? { get }
    var version: NSNumber? { get }
}

public extension Dummy1Type {
    public func primaryKey() -> String {
        return "id"
    }
    
    public func primaryValue() -> String? {
        return id
    }
    
    public func stringRepresentationForResult() -> String {
        return id.getOrElse("")
    }
}

public final class CDDummy1: NSManagedObject {
    @NSManaged public var id: String?
    @NSManaged public var int64: NSNumber?
    @NSManaged public var date: Date?
    @NSManaged public var float: NSNumber?
    @NSManaged public var version: NSNumber?
    
    public var sectionName: String? {
        if let id = self.id {
            let section = String(describing: id)
            return section.count == 1 ? section : section.dropLast().description
        } else {
            return nil
        }
    }
}

public final class Dummy1 {
    fileprivate static var counter = 0
    
    fileprivate var _id: String?
    fileprivate var _int64: NSNumber?
    fileprivate var _date: Date?
    fileprivate var _float: NSNumber?
    fileprivate var _version: NSNumber?
    
    public var id: String? {
        return _id
    }
    
    public var int64: NSNumber? {
        return _int64
    }
    
    public var date: Date? {
        return _date
    }
    
    public var float: NSNumber? {
        return _float
    }
    
    public var version: NSNumber? {
        return _version
    }
    
    public init() {
        Dummy1.counter += 1
        let counter = Dummy1.counter
        _id = String(describing: counter)
        _date = Date.random()
        _int64 = Int64(Int.randomBetween(0, 10000)) as NSNumber
        _float = Float(Int.randomBetween(0, 10000)) as NSNumber
        _version = 1
    }
}

extension CDDummy1: Dummy1Type {}

extension CDDummy1: HMCDVersionableMasterType {
    public typealias PureObject = Dummy1
    
    public static func cdAttributes() throws -> [NSAttributeDescription]? {
        return [
            NSAttributeDescription.builder()
                .with(name: "id")
                .with(type: .stringAttributeType)
                .shouldNotBeOptional()
                .build(),
            
            NSAttributeDescription.builder()
                .with(name: "int64")
                .with(type: .integer64AttributeType)
                .shouldNotBeOptional()
                .build(),
            
            NSAttributeDescription.builder()
                .with(name: "date")
                .with(type: .dateAttributeType)
                .shouldNotBeOptional()
                .build(),
            
            NSAttributeDescription.builder()
                .with(name: "float")
                .with(type: .floatAttributeType)
                .shouldNotBeOptional()
                .build(),
            
            NSAttributeDescription.builder()
                .with(name: "version")
                .with(type: .integer16AttributeType)
                .shouldNotBeOptional()
                .build()
        ]
    }
    
    public func mutateWithPureObject(_ object: PureObject) {
        id = object.id
        date = object.date
        float = object.float
        int64 = object.int64
        version = object.version
    }
    
    public func currentVersion() -> String? {
        if let version = self.version {
            return String(describing: version)
        } else {
            return nil
        }
    }
    
    public func oneVersionHigher() -> String? {
        if let version = self.version {
            return String(describing: version.intValue + 1)
        } else {
            return nil
        }
    }
    
    public func hasPreferableVersion(over obj: HMVersionableType) throws -> Bool {
        if let v1 = self.currentVersion(), let v2 = obj.currentVersion() {
            return v1 >= v2
        } else {
            throw Exception("Version not available")
        }
    }
    
    public func mergeWithOriginalVersion(_ obj: HMVersionableType) throws {}
    
    public func updateVersion(_ version: String?) {
        if let version = version, let dbl = Double(version) {
            self.version = NSNumber(value: dbl).intValue as NSNumber
        }
    }
}

extension Dummy1: Equatable {
    public static func ==(lhs: Dummy1, rhs: Dummy1) -> Bool {
        // We don't compare the version here because it will be bumped when
        // an update is successful. During testing, we only compare the other
        // properties to make sure that the updated object is the same as this.
        return lhs.id == rhs.id &&
            lhs.date == rhs.date &&
            lhs.int64 == rhs.int64 &&
            lhs.float == rhs.float
    }
}

extension Dummy1: IdentifiableType {
    public var identity: String {
        return id ?? ""
    }
}

extension Dummy1: Dummy1Type {}

extension Dummy1: CustomStringConvertible {
    public var description: String {
        return ""
            + "id: \(String(describing: id)), "
            + "int64: \(String(describing: int64)), "
            + "float: \(String(describing: float)), "
            + "date: \(String(describing: date)), "
            + "version: \(String(describing: version))"
    }
}

extension Dummy1: HMCDPureObjectMasterType {
    public typealias CDClass = CDDummy1

    public static func builder() -> Builder {
        return Builder()
    }
    
    public final class Builder {
        private let d1: Dummy1
        
        fileprivate init() {
            d1 = Dummy1()
        }
        
        @discardableResult
        public func with(id: String?) -> Self {
            d1._id = id
            return self
        }
        
        @discardableResult
        public func with(date: Date?) -> Self {
            d1._date = date
            return self
        }
        
        @discardableResult
        public func with(int64: NSNumber?) -> Self {
            d1._int64 = int64
            return self
        }
        
        @discardableResult
        public func with(float: NSNumber?) -> Self {
            d1._float = float
            return self
        }
        
        @discardableResult
        public func with(version: NSNumber?) -> Self {
            d1._version = version
            return self
        }
        
        @discardableResult
        public func with(version: String?) -> Self {
            if let version = version, let dbl = Double(version) {
                return with(version: NSNumber(value: dbl).intValue as NSNumber)
            } else {
                return self
            }
        }
        
        @discardableResult
        public func with(json: [String : Any?]) -> Self {
            return self
                .with(id: json["id"] as? String)
                .with(date: json["date"] as? Date)
                .with(int64: json["int64"] as? NSNumber)
                .with(float: json["float"] as? NSNumber)
                .with(version: json["version"] as? NSNumber)
        }
        
        public func with(dummy1: Dummy1Type?) -> Self {
            if let dummy1 = dummy1 {
                return self
                    .with(id: dummy1.id)
                    .with(date: dummy1.date)
                    .with(int64: dummy1.int64)
                    .with(float: dummy1.float)
                    .with(version: dummy1.version)
            } else {
                return self
            }
        }
        
        public func build() -> Dummy1 {
            return d1
        }
    }
}

extension Dummy1.Builder: HMCDPureObjectBuilderMasterType {
    public typealias Buildable = Dummy1
    
    public func with(cdObject: Buildable.CDClass) -> Self {
        return with(dummy1: cdObject)
    }
    
    public func with(buildable: Buildable?) -> Self {
        if let buildable = buildable {
            return with(dummy1: buildable)
        } else {
            return self
        }
    }
}
