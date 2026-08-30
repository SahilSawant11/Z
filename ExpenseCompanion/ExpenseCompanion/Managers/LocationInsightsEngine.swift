//
//  LocationInsightsEngine.swift
//  ExpenseCompanion
//
//  Pure logic layer (no persistence, no UI) that:
//  1. Clusters nearby expenses into "location clusters" for map pin grouping.
//  2. Promotes clusters that pass a visit-count threshold into FrequentPlace
//     candidates (Home/Work/Gym/Cafe-style auto-detection).
//  3. Generates plain-English spending insights from those clusters.
//
//  Clustering is a simple greedy distance-threshold algorithm — fine for the
//  hundreds-of-expenses scale this app runs at. If that ever changes, swap in
//  a proper grid/k-d-tree based approach without touching any caller.
//

import Foundation
import CoreLocation

// MARK: - Location Cluster

/// A group of expenses that happened within `clusterRadiusMeters` of each other.
/// Used both for map pin grouping and as the raw material for insights.
struct LocationCluster: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let expenses: [Expense]

    var totalAmount: Double { expenses.reduce(0) { $0 + $1.amount } }
    var visitCount: Int { expenses.count }

    /// The most common category at this location — drives the pin color.
    var dominantCategory: ExpenseCategory {
        let counts = Dictionary(grouping: expenses, by: { $0.category }).mapValues(\.count)
        return counts.max(by: { $0.value < $1.value })?.key ?? .other
    }

    /// Best available display name: most common non-nil place name, falling back to locality.
    var displayName: String {
        let names = expenses.compactMap(\.placeName)
        if let mostCommon = mostFrequent(in: names) { return mostCommon }
        if let locality = expenses.compactMap(\.locality).first { return locality }
        return "Unnamed location"
    }

    var locality: String? {
        expenses.compactMap(\.locality).first
    }

    private func mostFrequent(in items: [String]) -> String? {
        guard !items.isEmpty else { return nil }
        let counts = Dictionary(grouping: items, by: { $0 }).mapValues(\.count)
        return counts.max(by: { $0.value < $1.value })?.key
    }
}

// MARK: - Insight

struct LocationInsight: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
}

// MARK: - Engine

enum LocationInsightsEngine {

    /// Expenses closer together than this are considered "the same place."
    /// ~120m covers a mall or office campus without merging genuinely distinct spots.
    static let clusterRadiusMeters: CLLocationDistance = 120

    /// A cluster needs at least this many visits before it's surfaced as a
    /// "frequent place" or used in comparative insights — avoids one-off noise.
    static let minVisitsForFrequentPlace = 3

    // MARK: Clustering

    /// Greedy single-pass clustering: walk the expenses, and either attach each
    /// one to the nearest existing cluster (if within radius) or start a new cluster.
    static func clusterExpenses(_ expenses: [Expense], radiusMeters: CLLocationDistance = clusterRadiusMeters) -> [LocationCluster] {
        let geotagged = expenses.filter { $0.hasLocation }
        guard !geotagged.isEmpty else { return [] }

        var clusters: [(center: CLLocationCoordinate2D, members: [Expense])] = []

        for expense in geotagged {
            guard let coordinate = expense.coordinate else { continue }
            let expenseLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

            if let index = clusters.firstIndex(where: { cluster in
                let clusterLocation = CLLocation(latitude: cluster.center.latitude, longitude: cluster.center.longitude)
                return clusterLocation.distance(from: expenseLocation) <= radiusMeters
            }) {
                clusters[index].members.append(expense)
                // Recompute centroid as a running average so the cluster center
                // drifts toward the true middle as more points join.
                clusters[index].center = centroid(of: clusters[index].members)
            } else {
                clusters.append((center: coordinate, members: [expense]))
            }
        }

        return clusters.map { LocationCluster(coordinate: $0.center, expenses: $0.members) }
    }

    private static func centroid(of expenses: [Expense]) -> CLLocationCoordinate2D {
        let coordinates = expenses.compactMap(\.coordinate)
        guard !coordinates.isEmpty else { return CLLocationCoordinate2D(latitude: 0, longitude: 0) }
        let latSum = coordinates.reduce(0) { $0 + $1.latitude }
        let lonSum = coordinates.reduce(0) { $0 + $1.longitude }
        return CLLocationCoordinate2D(latitude: latSum / Double(coordinates.count), longitude: lonSum / Double(coordinates.count))
    }

    // MARK: Frequent place promotion

    /// Clusters that qualify as "frequent places" — visited enough times to be
    /// worth labeling (Home/Work/Gym/Cafe) rather than a one-off errand.
    static func frequentPlaceCandidates(from clusters: [LocationCluster]) -> [LocationCluster] {
        clusters
            .filter { $0.visitCount >= minVisitsForFrequentPlace }
            .sorted { $0.visitCount > $1.visitCount }
    }

    // MARK: Insights

    /// Generates a handful of plain-English insights from the clustered data.
    /// Deliberately simple/explainable heuristics rather than a black-box model,
    /// so every sentence traces back to a number you could recompute by hand.
    static func generateInsights(clusters: [LocationCluster], allExpenses: [Expense], currencyCode: String) -> [LocationInsight] {
        var insights: [LocationInsight] = []
        let qualifying = frequentPlaceCandidates(from: clusters)
        guard !qualifying.isEmpty else { return insights }

        let overallAverage = allExpenses.isEmpty ? 0 : allExpenses.reduce(0) { $0 + $1.amount } / Double(allExpenses.count)

        // Most-visited place
        if let mostVisited = qualifying.first {
            insights.append(LocationInsight(
                icon: "figure.walk",
                text: "You've visited \(mostVisited.displayName) \(mostVisited.visitCount) times."
            ))
        }

        // Highest total spend location
        if let highestSpend = qualifying.max(by: { $0.totalAmount < $1.totalAmount }) {
            insights.append(LocationInsight(
                icon: "indianrupeesign.circle",
                text: "\(highestSpend.displayName): \(CurrencyFormatter.format(highestSpend.totalAmount, currencyCode: currencyCode)) total."
            ))
        }

        // Above-average spending location (the "you spend X% more here" insight)
        if overallAverage > 0 {
            for cluster in qualifying {
                let clusterAverage = cluster.totalAmount / Double(cluster.visitCount)
                let percentDiff = ((clusterAverage - overallAverage) / overallAverage) * 100
                if percentDiff >= 25 {
                    insights.append(LocationInsight(
                        icon: "chart.line.uptrend.xyaxis",
                        text: "You spend \(Int(percentDiff))% more per visit at \(cluster.displayName) than your average expense."
                    ))
                    break // one comparative insight is enough to avoid noise
                }
            }
        }

        // Dominant-category place
        if let categoryPlace = qualifying.first(where: { cluster in
            let dominantCount = cluster.expenses.filter { $0.category == cluster.dominantCategory }.count
            return Double(dominantCount) / Double(cluster.visitCount) >= 0.7
        }) {
            insights.append(LocationInsight(
                icon: categoryPlace.dominantCategory.symbolName,
                text: "Most of your spending at \(categoryPlace.displayName) is on \(categoryPlace.dominantCategory.rawValue.lowercased())."
            ))
        }

        return insights
    }
}
