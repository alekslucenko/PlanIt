import SwiftUI

struct TimeframeDropdownView: View {
    @Binding var selectedTimeframe: String
    let timeframes: [String]
    @State private var isExpanded = false
    @State private var hoveringItem: String?
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            // Dropdown Button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text(selectedTimeframe)
                        .font(.custom("Geist-Medium", size: 14))
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(.systemGray3))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.easeInOut(duration: 0.25), value: isExpanded)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6).opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray5).opacity(0.3), lineWidth: 0.5)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Dropdown Menu
            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(timeframes, id: \.self) { timeframe in
                        Button(action: {
                            selectedTimeframe = timeframe
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isExpanded = false
                            }
                        }) {
                            HStack {
                                Text(timeframe)
                                    .font(.custom("Geist-Medium", size: 14))
                                    .fontWeight(.medium)
                                    .foregroundColor(selectedTimeframe == timeframe ? .white : Color(.systemGray2))
                                
                                Spacer()
                                
                                if selectedTimeframe == timeframe {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color(red: 34/255, green: 197/255, blue: 94/255))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedTimeframe == timeframe ? 
                                          Color(.systemGray6).opacity(0.2) : 
                                          (hoveringItem == timeframe ? Color(.systemGray6).opacity(0.1) : Color.clear))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onHover { hovering in
                            hoveringItem = hovering ? timeframe : nil
                        }
                        
                        if timeframe != timeframes.last {
                            Divider()
                                .background(Color(.systemGray5).opacity(0.2))
                                .padding(.horizontal, 8)
                        }
                    }
                }
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 55/255, green: 65/255, blue: 81/255).opacity(0.9), // Gray-700
                                    Color(red: 31/255, green: 41/255, blue: 55/255).opacity(0.8)  // Gray-800
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray5).opacity(0.3), lineWidth: 0.5)
                        )
                        .shadow(
                            color: Color.black.opacity(0.3),
                            radius: 12,
                            x: 0,
                            y: 6
                        )
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95, anchor: .topTrailing)
                        .combined(with: .opacity)
                        .combined(with: .move(edge: .top)),
                    removal: .scale(scale: 0.95, anchor: .topTrailing)
                        .combined(with: .opacity)
                        .combined(with: .move(edge: .top))
                ))
                .zIndex(1000)
                .offset(y: 6)
            }
        }
        .frame(width: 150)
        .onTapGesture {
            // Prevent tap from propagating
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 40) {
            TimeframeDropdownView(
                selectedTimeframe: .constant("Today"),
                timeframes: ["Today", "This Week", "Last 30 Days", "Last 3 Months"]
            )
            
            TimeframeDropdownView(
                selectedTimeframe: .constant("This Week"),
                timeframes: ["Today", "This Week", "Last 30 Days", "Last 3 Months"]
            )
        }
        .padding()
    }
    .preferredColorScheme(.dark)
} 