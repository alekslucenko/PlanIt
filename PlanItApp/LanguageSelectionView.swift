import SwiftUI

struct LanguageSelectionView: View {
    @StateObject private var localizationManager = LocalizationManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showConfirmationAlert = false
    @State private var selectedLanguage: SupportedLanguage = .english
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                themeManager.backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "globe")
                                .font(.system(size: 50, weight: .medium))
                                .foregroundColor(themeManager.isDarkMode ? themeManager.neonBlue : themeManager.accentBlue)
                                .padding(.top, 20)
                            
                            Text("select_language".localized)
                                .font(.system(size: 28, weight: .bold))
                                .themedText(.primary)
                            
                            Text("Change the app language to your preference")
                                .font(.system(size: 16))
                                .themedText(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 20)
                        
                        // Language Options
                        VStack(spacing: 12) {
                            ForEach(SupportedLanguage.allCases) { language in
                                LanguageRow(
                                    language: language,
                                    isSelected: language == localizationManager.currentLanguage,
                                    onTap: {
                                        selectedLanguage = language
                                        if language != localizationManager.currentLanguage {
                                            showConfirmationAlert = true
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            .navigationTitle("language".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                    .foregroundColor(themeManager.isDarkMode ? themeManager.neonBlue : themeManager.accentBlue)
                }
            }
        }
        .alert("Change Language", isPresented: $showConfirmationAlert) {
            Button("cancel".localized, role: .cancel) {}
            Button("Change") {
                changeLanguage(to: selectedLanguage)
            }
        } message: {
            Text("The app language will be changed to \(selectedLanguage.displayName). The app may need to restart to apply all changes.")
        }
    }
    
    private func changeLanguage(to language: SupportedLanguage) {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            localizationManager.setLanguage(language)
        }
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Auto-dismiss after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
}

struct LanguageRow: View {
    let language: SupportedLanguage
    let isSelected: Bool
    let onTap: () -> Void
    
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Flag
                Text(language.flag)
                    .font(.system(size: 32))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(language.displayName)
                        .font(.system(size: 18, weight: .semibold))
                        .themedText(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(language.nativeName)
                        .font(.system(size: 14, weight: .medium))
                        .themedText(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
                
                selectionIndicator
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(backgroundView)
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var selectionIndicator: some View {
        Group {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(themeManager.isDarkMode ? themeManager.neonGreen : themeManager.accentGreen)
            } else {
                Image(systemName: "circle")
                    .font(.system(size: 24, weight: .medium))
                    .themedText(.secondary)
            }
        }
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(backgroundFill)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(strokeColor, lineWidth: isSelected ? 2 : 1)
            )
    }
    
    private var backgroundFill: Color {
        if isSelected {
            return themeManager.isDarkMode ? themeManager.neonGreen.opacity(0.1) : themeManager.accentGreen.opacity(0.1)
        } else {
            return themeManager.isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.05)
        }
    }
    
    private var strokeColor: Color {
        if isSelected {
            return themeManager.isDarkMode ? themeManager.neonGreen.opacity(0.3) : themeManager.accentGreen.opacity(0.3)
        } else {
            return themeManager.isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1)
        }
    }
}

#Preview {
    LanguageSelectionView()
} 