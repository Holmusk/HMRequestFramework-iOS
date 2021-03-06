//
//  HMCDSections.swift
//  HMRequestFramework
//
//  Created by Hai Pham on 9/1/17.
//  Copyright © 2017 Holmusk. All rights reserved.
//

/// Utility class for HMCDSection.
public final class HMCDSections {
    
    /// Get the object for a particular index path from a Sequence of sections.
    ///
    /// - Parameters:
    ///   - sections: A Sequence of HMCDSectionType.
    ///   - indexPath: An IndexPath instance.
    /// - Returns: A ST.V instance.
    public static func object<ST,S>(_ sections: S,
                                    _ indexPath: IndexPath) -> ST.V? where
        ST: HMCDSectionType, S: Sequence, S.Element == ST
    {
        let sections = sections.map({$0})
        let section = indexPath.section
        let row = indexPath.row
        return sections.element(at: section)?.objects.element(at: row)
    }
    
    /// Get sliced sections from a Sequence of sections so that the total number
    /// of objects do not exceed a limit.
    ///
    /// - Parameters:
    ///   - sections: A Sequence of sections.
    ///   - limit: An Int value.
    /// - Returns: An Array of sections.
    public static func sectionsWithLimit<ST,S>(_ sections: S,
                                               _ limit: Int) -> [ST] where
        ST: HMCDSectionType, S: Sequence, S.Element == ST
    {
        var sliced = [ST]()
        
        for section in sections {
            let sectionLimit = limit - sliced.reduce(0, {$1.numberOfObjects + $0})
            
            if sectionLimit > 0 {
                sliced.append(section.withObjectLimit(sectionLimit))
            } else {
                break
            }
        }
        
        return sliced
    }
    
    private init() {}
}
