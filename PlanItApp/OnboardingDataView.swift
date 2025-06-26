import SwiftUI

struct OnboardingDataView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var onboardingManager: OnboardingManager
    @State private var showingClearAlert = false
    @State private var jsonString = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if onboardingManager.hasCompletedOnboarding {
                        // Summary Section
                        summarySection
                        
                        // Categories Section
                        categoriesSection
                        
                        // Responses Section
                        responsesSection
                        
                        // Raw JSON Section
                        jsonSection
                        
                        // Actions Section
                        actionsSection
                    } else {
                        emptyStateView
                    }
                }
                .padding()
            }
            .navigationTitle("Onboarding Data")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadJsonData()
        }
        .alert("Reset Onboarding", isPresented: $showingClearAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                onboardingManager.clearOnboardingData()
                dismiss()
            }
        } message: {
            Text("This will clear all onboarding data and the user will need to complete onboarding again. This action cannot be undone.")
        }
    }
    
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundColor(.blue)
                Text("Summary")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            if let data = onboardingManager.onboardingData {
                VStack(spacing: 8) {
                    InfoRow(label: "Completed", value: DateFormatter.localizedString(from: data.completedAt, dateStyle: .medium, timeStyle: .short))
                    InfoRow(label: "App Version", value: data.appVersion)
                    InfoRow(label: "Device", value: "\(data.deviceInfo.deviceModel) (\(data.deviceInfo.systemVersion))")
                    InfoRow(label: "Screen Size", value: data.deviceInfo.screenSize)
                    InfoRow(label: "Categories", value: "\(data.selectedCategories.count)")
                    InfoRow(label: "Responses", value: "\(data.responses.count)")
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "square.grid.2x2")
                    .foregroundColor(.green)
                Text("Selected Categories")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            if let data = onboardingManager.onboardingData {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(data.selectedCategories, id: \.self) { category in
                        HStack(spacing: 8) {
                            Image(systemName: category.iconName)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(hex: category.color))
                            
                            Text(category.displayName)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: category.color).opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(hex: category.color).opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var responsesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right")
                    .foregroundColor(.purple)
                Text("Question Responses")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            if let data = onboardingManager.onboardingData {
                LazyVStack(spacing: 12) {
                    ForEach(Array(data.responses.enumerated()), id: \.element.questionId) { index, response in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Q\(index + 1)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(.purple)
                                    )
                                
                                Text(response.questionId)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text(getCategoryDisplayName(response.categoryId))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                if let options = response.selectedOptions {
                                    Text("Selected: \(options.joined(separator: ", "))")
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                }
                                
                                if let sliderValue = response.sliderValue {
                                    Text("Value: \(String(format: "%.1f", sliderValue))")
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                }
                                
                                if let ratingValue = response.ratingValue {
                                    Text("Rating: \(ratingValue) stars")
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                }
                                
                                if let textValue = response.textValue {
                                    Text("Text: \(textValue)")
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.gray.opacity(0.1))
                        )
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var jsonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.orange)
                Text("Raw JSON Data")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Copy") {
                    UIPasteboard.general.string = jsonString
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.orange)
                )
            }
            
            ScrollView {
                Text(jsonString)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 200)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.gray.opacity(0.1))
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                showingClearAlert = true
            }) {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(.white)
                    Text("Reset Onboarding Data")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [.red, .red.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.6))
            
            Text("No Onboarding Data")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
            
            Text("The user hasn't completed onboarding yet. Complete the onboarding flow to see data here.")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    private func loadJsonData() {
        jsonString = onboardingManager.exportOnboardingDataAsJSON()
    }
    
    private func getCategoryDisplayName(_ categoryId: String) -> String {
        return OnboardingCategory(rawValue: categoryId)?.displayName ?? categoryId
    }
}

// Helper view for info rows
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    OnboardingDataView(onboardingManager: OnboardingManager())
} 