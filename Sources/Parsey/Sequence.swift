//
//  Sequence.swift
//  Funky
//
//  Created by Richard Wei on 4/24/17.
//
//

public extension Sequence {

    typealias Element = Iterator.Element

    /// Returns true if all elements satisfy the predicate
    func forAll(_ predicate: (Element) -> Bool) -> Bool {
        return reduce(true, { $0 && predicate($1) })
    }

    /// `mapM` for a combination of Array and Optional
    /// - Note: Better have HKT, of course
    func liftedMap(_ transform: (Element) -> Element?) -> [Element]? {
        var result: [Element] = []
        for x in self {
            guard let new = transform(x) else { return nil }
            result.append(new)
        }
        return result
    }

}
