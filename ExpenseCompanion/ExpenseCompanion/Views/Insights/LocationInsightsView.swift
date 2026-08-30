//
//  LocationInsightsView.swift
//  ExpenseCompanion
//
//  Surfaces the generated insights ("You spend 40% more at X") and the list
//  of saved frequent places with their monthly spend. Embedded into the Stats
//  tab rather than a standalone tab, since it's most useful alongside the
//  category breakdown someone's already looking at.
//

import SwiftUI
import SwiftData
import CoreLocation

struct LocationInsightsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var clusters: [LocationCluster] = []
    @State private var insights: [LocationInsight] = []
    @State private var savedPlaces: [FrequentPlace] = []
    @State private var currencyCode = "INR"

    var body: some View {
        VStack(spacing: 16) {
            if !insights.isEmpty {
                insightsCard
            }
            if !frequentPlaceClusters.isEmpty {
                frequentPlacesCard
            }
        }
        .onAppear(perform: load)
    }

    private var frequentPlaceClusters: [LocationCluster] {
        LocationInsightsEngine.frequentPlaceCandidates(from: clusters)
    }

    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            GlassSectionHeader(title: "Location Insights", systemImage: "lightbulb.fill")
            ForEach(insights) { insight in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: insight.icon)
                        .foregroundStyle(.purple)
                        .frame(width: 20)
                    Text(insight.text)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .glassCard()
    }

    private var frequentPlacesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            GlassSectionHeader(title: "Frequent Places", systemImage: "mappin.and.ellipse")
            ForEach(frequentPlaceClusters) { cluster in
                HStack {
                    Circle()
                        .fill(cluster.dominantCategory.color.opacity(0.2))
                        .frame(width: 36, height: 36)
                        .overlay(Image(systemName: cluster.dominantCategory.symbolName).font(.caption).foregroundStyle(cluster.dominantCategory.color))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(savedLabel(for: cluster) ?? cluster.displayName)
                            .font(.subheadline.weight(.semibold))
                        Text("\(cluster.visitCount) visits")
                            .font(.caption)
                            .opacity(0.6)
                    }

                    Spacer()

                    Text(CurrencyFormatter.format(cluster.totalAmount, currencyCode: currencyCode))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
            }
        }
        .glassCard()
    }

    private func savedLabel(for cluster: LocationCluster) -> String? {
        savedPlaces.first { place in
            let placeCoord = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
            let clusterLoc = CLLocation(latitude: cluster.coordinate.latitude, longitude: cluster.coordinate.longitude)
            let placeLoc = CLLocation(latitude: placeCoord.latitude, longitude: placeCoord.longitude)
            return clusterLoc.distance(from: placeLoc) <= 100
        }?.label
    }

    private func load() {
        let expenseRepo = ExpenseRepository(context: modelContext)
        let placeRepo = PlaceRepository(context: modelContext)
        let goalRepo = GoalRepository(context: modelContext)

        let allExpenses = (try? expenseRepo.allExpenses()) ?? []
        clusters = LocationInsightsEngine.clusterExpenses(allExpenses)
        savedPlaces = (try? placeRepo.allPlaces()) ?? []
        currencyCode = (try? goalRepo.fetchOrCreateBudgetSettings())?.currencyCode ?? "INR"
        insights = LocationInsightsEngine.generateInsights(clusters: clusters, allExpenses: allExpenses, currencyCode: currencyCode)
    }
}
