import SwiftUI
import CoreLocation

// MARK: - Onboarding Step: Location Permission & Selection
/// This view is shown as the very first onboarding step. It asks the user to grant
/// CoreLocation permission and confirms that we have a valid `selectedLocation` in
/// `LocationManager` before allowing the user to continue.
struct LocationPermissionStepView: View {
    @EnvironmentObject var locationManager: LocationManager
    /// Called when the user taps Continue and a location is available.
    let onNext: () -> Void
    /// Called when the user wants to skip (uses default fallback location).
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "location.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(.bottom, 8)

            Text("Let us know where you are")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Text("PlanIt needs your location to recommend nearby places and events tailored to you.")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let error = locationManager.locationError {
                Text(error)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Current selection preview
            if let selected = locationManager.selectedLocation {
                VStack(spacing: 4) {
                    Text("Selected: ")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    Text(locationManager.selectedLocationName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.top, 8)
            }

            Spacer()

            VStack(spacing: 16) {
                Button(action: {
                    locationManager.requestLocationPermission()
                }) {
                    HStack {
                        if locationManager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text(locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways ? "Refresh Location" : "Allow Location Access")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.9))
                    .cornerRadius(16)
                }
                .disabled(locationManager.isLoading)
                .padding(.horizontal, 40)

                NavigationButtonsView(
                    showBackButton: false,
                    backAction: {},
                    continueTitle: "Continue",
                    continueAction: onNext,
                    isContinueDisabled: locationManager.selectedLocation == nil
                )
            }
        }
    }
}

#Preview {
    LocationPermissionStepView(onNext: {}, onSkip: {})
        .environmentObject(LocationManager())
        .padding()
        .background(Color.black)
} 