import SwiftUI

struct JSONContentView: View {
    @Environment(\.dismiss) private var dismiss
    let jsonContent: String
    @State private var showingCopyAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundView
                contentView
            }
            .navigationTitle("JSON File")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                toolbarContent
            }
        }
        .alert("Copied!", isPresented: $showingCopyAlert) {
            Button("OK") {}
        } message: {
            Text("JSON content has been copied to clipboard")
        }
    }
    
    private var backgroundView: some View {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()
    }
    
    private var contentView: some View {
        Group {
            if jsonContent.isEmpty || jsonContent.hasPrefix("Error") {
                errorStateView
            } else {
                jsonContentView
            }
        }
    }
    
    private var errorStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.below.ecg")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.6))
            
            Text("JSON File")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
            
            Text(jsonContent.isEmpty ? "No JSON file found" : jsonContent)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var jsonContentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                fileInfoSection
                jsonSection
                usageInfoSection
            }
            .padding()
        }
    }
    
    private var fileInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text.below.ecg")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                Text("onboarding_data.json")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                copyButton
            }
            
            Text("Onboarding data stored in app documents directory")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding()
        .background(infoCardBackground(.blue))
    }
    
    private var copyButton: some View {
        Button("Copy") {
            UIPasteboard.general.string = jsonContent
            showingCopyAlert = true
        }
        .font(.system(size: 16, weight: .medium))
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [.blue, .blue.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(8)
    }
    
    private var jsonSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "curlybraces")
                    .foregroundColor(.green)
                    .font(.title3)
                
                Text("JSON Content")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            ScrollView {
                Text(jsonContent)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                    )
            }
            .frame(maxHeight: 400)
        }
        .padding()
        .background(infoCardBackground(.green))
    }
    
    private var usageInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.orange)
                    .font(.title3)
                
                Text("Usage Information")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            usageInfoList
        }
        .padding()
        .background(infoCardBackground(.orange))
    }
    
    private var usageInfoList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("• This file is automatically created when onboarding is completed")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Text("• Contains user preferences and responses for personalization")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Text("• Can be used for analytics, debugging, or data export")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Text("• File is stored locally in app's documents directory")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }
    
    private func infoCardBackground(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
    }
    
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Done") {
                dismiss()
            }
        }
    }
}

#Preview {
    JSONContentView(jsonContent: """
    {
      "selectedCategories": ["restaurants", "nature"],
      "responses": [
        {
          "questionId": "restaurants_cuisine",
          "categoryId": "restaurants",
          "selectedOptions": ["Italian", "Asian"],
          "timestamp": "2023-12-06T15:30:00Z"
        }
      ],
      "completedAt": "2023-12-06T15:30:00Z",
      "appVersion": "1.0"
    }
    """)
} 