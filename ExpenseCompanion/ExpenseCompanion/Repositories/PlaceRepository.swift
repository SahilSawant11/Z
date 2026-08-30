//
//  PlaceRepository.swift
//  ExpenseCompanion
//

import Foundation
import SwiftData
import CoreLocation

@MainActor
final class PlaceRepository {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func allPlaces() throws -> [FrequentPlace] {
        try context.fetch(FetchDescriptor<FrequentPlace>())
    }

    func add(_ place: FrequentPlace) throws {
        context.insert(place)
        try context.save()
    }

    func delete(_ place: FrequentPlace) throws {
        context.delete(place)
        try context.save()
    }

    func rename(_ place: FrequentPlace, to label: String) throws {
        place.label = label
        try context.save()
    }

    func setSpendingLimit(_ limit: Double?, for place: FrequentPlace) throws {
        place.spendingLimit = limit
        try context.save()
    }

    /// Finds an existing saved place within `matchRadiusMeters` of a coordinate, if any.
    /// Used to avoid creating duplicate FrequentPlace rows for the same real-world spot.
    func existingPlace(near coordinate: CLLocationCoordinate2D, matchRadiusMeters: CLLocationDistance = 100) throws -> FrequentPlace? {
        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return try allPlaces().first { place in
            let placeLocation = CLLocation(latitude: place.latitude, longitude: place.longitude)
            return placeLocation.distance(from: target) <= matchRadiusMeters
        }
    }
}
