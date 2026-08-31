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
                Color.appBackground.ignoresSafeArea()
                RadialGradient(
                    colors: [expense.category.color.opacity(0.2), Color.clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 300
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        // Hero
                        VStack(spacing: 14) {
                            CategoryBadge(category: expense.category, size: 64)
                                .shadow(color: expense.category.color.opacity(0.4), radius: 16, x: 0, y: 8)

                            Text(CurrencyFormatter.format(expense.amount))
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(Color.textPrimary)

                            Text(expense.category.rawValue.uppercased())
                                .font(.system(size: 11, weight: .semibold))
                                .kerning(1.5)
                                .foregroundStyle(Color.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .glassCard()

                        if !expense.note.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                GlassSectionHeader(title: "Note", systemImage: "text.alignleft")
                                Text(expense.note)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassCard()
                        }

                        if let coordinate = expense.coordinate {
                            VStack(alignment: .leading, spacing: 10) {
                                GlassSectionHeader(title: expense.placeName ?? "Location", systemImage: "mappin.and.ellipse")
                                if let locality = expense.locality {
                                    Text(locality)
                                        .font(.caption)
                                        .foregroundStyle(Color.textTertiary)
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

                        VStack(alignment: .leading, spacing: 10) {
                            GlassSectionHeader(title: "Date", systemImage: "calendar")
                            Text(expense.date.formatted(date: .long, time: .shortened))
                                .font(.subheadline)
                                .foregroundStyle(Color.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard()

                        // Delete
                        Button(role: .destructive) {
                            showingDeleteConfirm = true
                        } label: {
                            Label("Delete Expense", systemImage: "trash")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color.red.opacity(0.12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .strokeBorder(Color.red.opacity(0.25), lineWidth: 1)
                                        )
                                )
                                .foregroundStyle(Color.red.opacity(0.85))
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
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
