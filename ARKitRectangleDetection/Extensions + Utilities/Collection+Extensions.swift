//
//  Collection+Extensions.swift
//  ARKitRectangleDetection
//
//  Created by Melissa Ludowise on 8/3/17.
//  Copyright © 2017 Mel Ludowise. All rights reserved.
//

import Foundation

// Filters the given collections to their interesection where comparator returns that the values are the same
// Returns an array of filtered collections
func filterByIntersection<C: Collection, E>(_ collections: [C], where comparator: (E, E) -> Bool) -> [[E]] where E == C.Element {
    var results: [[E]] = []
    
    for currentCollection in collections {
        var resultingCollection: [E] = []
        
        for item1 in currentCollection {
            let keepItem = collections.reduce(true, { (isContained, c) -> Bool in
                isContained && c.contains(where: { (item2) -> Bool in
                    comparator(item1, item2)
                })
            })
            if keepItem {
                resultingCollection.append(item1)
            }
        }
        
        results.append(resultingCollection)
    }
    
    return results
}

//extension Collection {
//    func intersect<C: Collection>(_ collection: C, where comparator: (Self.Element, Self.Element) -> Bool) -> [Self.Element] where C.Element == Self.Element {
//        var result: [Self.Element] = []
//
//        for item1 in self {
//            let isCommon = collection.contains(where: { (item2) -> Bool in
//                return comparator(item1, item2)
//            })
//
//            if isCommon {
//                result.append(item1)
//            }
//        }
//
//        return result
//    }
    
//    func intersect<C: Collection>(_ collection: C, where comparator: (Self.Element, Self.Element) -> Bool) -> ([Self.Element], [Self.Element]) where C.Element == Self.Element {
    
//}

//extension Array where Element:Equatable {
//    func intersect<C: Collection>(_ collection: C) -> [Element] where C.Element == Element {
//        return self.intersect(collection, where: { (item1, item2) -> Bool in
//            item1 == item2
//        })
//    }
//
//}
//
//fileprivate func intersect<C: Collection, E>(_ collections: [C], where comparator: (E, E) -> Bool) -> [E] where E == C.Element {
//    var collections = collections
//    var result: [E] = Array(collections.removeFirst())
//
//    for collection in collections {
//        result = result.intersect(collection, where: comparator)
//    }
//
//    return result
//}
//
//func intersect<C: Collection, E>(_ collections: C..., where comparator: (E, E) -> Bool) -> [E] where E == C.Element {
//    return intersect(collections, where: comparator)
//}
//
//func intersect<C: Collection, E:Equatable>(_ collections: C...) -> [E] where E == C.Element {
//    return intersect(collections, where: { (item1, item2) -> Bool in
//        item1 == item2
//    })
//}

