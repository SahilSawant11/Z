//
//  LocationInsightsView.swift
//  ExpenseCompanion
//
//  Surfaces location-based insights and frequent-place spend summaries.
//  Embedded at the bottom of the Stats tab.
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
        VStack(spacing: 14) {
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

    // MARK: - Insights Card

    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            GlassSectionHeader(title: "Location Insights", systemImage: "lightbulb.fill")
            ForEach(insights) { insight in
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.heroPink.opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: insight.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.heroPink)
                    }
                    Text(insight.text)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .glassCard()
    }

    // MARK: - Frequent Places Card

    private var frequentPlacesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            GlassSectionHeader(title: "Frequent Places", systemImage: "mappin.and.ellipse")
                .padding(.bottom, 10)
            ForEach(Array(frequentPlaceClusters.enumerated()), id: \.element.id) { idx, cluster in
                HStack(spacing: 14) {
                    CategoryBadge(category: cluster.dominantCategory, size: 38)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(savedLabel(for: cluster) ?? cluster.displayName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                        Text("\(cluster.visitCount) visits")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.textTertiary)
                    }

                    Spacer()

                    Text(CurrencyFormatter.format(cluster.totalAmount, currencyCode: currencyCode))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.textPrimary)
                }
                .padding(.vertical, 8)

                if idx < frequentPlaceClusters.count - 1 {
                    Divider().background(Color.white.opacity(0.07))
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
