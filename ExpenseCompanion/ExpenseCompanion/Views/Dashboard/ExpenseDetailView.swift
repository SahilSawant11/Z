//
//  ExpenseDetailView.swift
//  ExpenseCompanion
//

import SwiftUI
import MapKit
import SwiftData

struct ExpenseDetailView: View {
    let expense: Expense
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showingDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                DynamicGradientBackground()

                ScrollView {
                    VStack(spacing: 14) {
                        // Hero card
                        VStack(spacing: 12) {
                            CategoryBadge(category: expense.category, size: 64)
                                .shadow(color: expense.category.color.opacity(0.35), radius: 12, x: 0, y: 6)

                            Text(CurrencyFormatter.format(expense.amount))
                                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                                .monospacedDigit()

                            Text(expense.category.rawValue)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .glassCard()

                        if !expense.note.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                GlassSectionHeader(title: "Note", systemImage: "text.alignleft")
                                Text(expense.note)
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassCard()
                        }

                        if let coordinate = expense.coordinate {
                            VStack(alignment: .leading, spacing: 8) {
                                GlassSectionHeader(title: expense.placeName ?? "Location", systemImage: "mappin.and.ellipse")
                                if let locality = expense.locality {
                                    Text(locality)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Map(position: $cameraPosition) {
                                    Marker(expense.placeName ?? "Expense", coordinate: coordinate)
                                        .tint(expense.category.color)
                                }
                                .frame(height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .onAppear {
                                    cameraPosition = .region(
                                        MKCoordinateRegion(
                                            center: coordinate,
                                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                        )
                                    )
                                }
                            }
                            .glassCard()
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            GlassSectionHeader(title: "Date", systemImage: "calendar")
                            Text(expense.date.formatted(date: .long, time: .shortened))
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard()

                        // Delete button
                        Button(role: .destructive) {
                            showingDeleteConfirm = true
                        } label: {
                            Label("Delete Expense", systemImage: "trash")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.red.opacity(0.12))
                                )
                                .foregroundStyle(.red)
                        }
                        .confirmationDialog("Delete this expense?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                            Button("Delete", role: .destructive) {
                                modelContext.delete(expense)
                                try? modelContext.save()
                                dismiss()
                            }
                            Button("Cancel", role: .cancel) {}
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Expense Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
