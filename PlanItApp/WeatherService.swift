import Foundation
import CoreLocation
import Combine

class WeatherService: ObservableObject {
    private let apiKey = "bd5e378503939ddaee76f12ad7a97608" // OpenWeatherMap API key
    private let baseURL = "https://api.openweathermap.org/data/2.5"
    
    @Published var currentWeather: WeatherData?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var currentTask: URLSessionDataTask?
    
    func fetchWeather(for location: CLLocation) {
        // Cancel any existing request
        currentTask?.cancel()
        
        isLoading = true
        errorMessage = nil
        
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        let urlString = "\(baseURL)/weather?lat=\(lat)&lon=\(lon)&appid=\(apiKey)&units=imperial"
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid weather URL")
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Invalid weather request URL"
            }
            return
        }
        
        print("🌤️ Fetching weather for location: \(lat), \(lon)")
        
        // Create request with timeout
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        currentTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.currentTask = nil
                self.isLoading = false
                
                // Check for cancellation
                if let error = error as NSError?, error.code == NSURLErrorCancelled {
                    return
                }
                
                if let error = error {
                    print("❌ Weather fetch error: \(error.localizedDescription)")
                    self.errorMessage = "Failed to fetch weather: \(error.localizedDescription)"
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Invalid weather response")
                    self.errorMessage = "Invalid weather response"
                    return
                }
                
                print("🌤️ Weather API HTTP Status: \(httpResponse.statusCode)")
                
                guard httpResponse.statusCode == 200 else {
                    print("❌ Weather API HTTP Error: \(httpResponse.statusCode)")
                    self.errorMessage = "Weather service unavailable (HTTP \(httpResponse.statusCode))"
                    return
                }
                
                guard let data = data else {
                    print("❌ No weather data received")
                    self.errorMessage = "No weather data received"
                    return
                }
                
                do {
                    let weatherResponse = try JSONDecoder().decode(OpenWeatherResponse.self, from: data)
                    
                    // Validate response data
                    guard !weatherResponse.weather.isEmpty else {
                        print("❌ Empty weather data in response")
                        self.errorMessage = "Invalid weather data received"
                        return
                    }
                    
                    self.currentWeather = WeatherData(from: weatherResponse)
                    print("✅ Weather loaded: \(weatherResponse.main.temp)°F, \(weatherResponse.weather.first?.main ?? "Unknown")")
                    
                    // Clear any previous errors
                    self.errorMessage = nil
                    
                } catch {
                    print("❌ Weather decode error: \(error)")
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("📄 Raw weather response: \(jsonString)")
                    }
                    self.errorMessage = "Failed to parse weather data"
                }
            }
        }
        
        currentTask?.resume()
    }
    
    func retryWeatherFetch(for location: CLLocation) {
        print("🔄 Retrying weather fetch...")
        fetchWeather(for: location)
    }
    
    func clearWeatherData() {
        currentTask?.cancel()
        currentTask = nil
        currentWeather = nil
        errorMessage = nil
        isLoading = false
    }
    
    // MARK: - Async Methods for RecommendationEngine
    
    func getCurrentWeather(for location: CLLocation) async -> WeatherData? {
        return await withCheckedContinuation { continuation in
            // Set up a one-time publisher to wait for the weather data
            var cancellable: AnyCancellable?
            
            // First, trigger the fetch
            fetchWeather(for: location)
            
            // Then wait for the result
            cancellable = $currentWeather
                .first { _ in !self.isLoading } // Wait until loading is complete
                .sink { weatherData in
                    continuation.resume(returning: weatherData)
                    cancellable?.cancel()
                }
        }
    }
}

// MARK: - Weather Models

struct WeatherData: Equatable {
    let temperature: Int
    let condition: String
    let iconName: String
    let cityName: String
    let humidity: Int
    let description: String
    
    init(from response: OpenWeatherResponse) {
        self.temperature = Int(response.main.temp)
        self.condition = response.weather.first?.main ?? "Unknown"
        self.iconName = WeatherData.systemIconName(for: response.weather.first?.main ?? "Unknown")
        self.cityName = response.name
        self.humidity = response.main.humidity
        self.description = response.weather.first?.description.capitalized ?? "Unknown conditions"
    }
    
    static func systemIconName(for condition: String) -> String {
        let lowercased = condition.lowercased()
        
        if lowercased.contains("clear") {
            return "sun.max.fill"
        } else if lowercased.contains("clouds") {
            if lowercased.contains("few") || lowercased.contains("scattered") {
                return "cloud.sun.fill"
            } else {
                return "cloud.fill"
            }
        } else if lowercased.contains("rain") || lowercased.contains("drizzle") {
            return "cloud.rain.fill"
        } else if lowercased.contains("thunderstorm") {
            return "cloud.bolt.rain.fill"
        } else if lowercased.contains("snow") {
            return "cloud.snow.fill"
        } else if lowercased.contains("mist") || lowercased.contains("fog") || lowercased.contains("haze") {
            return "cloud.fog.fill"
        } else if lowercased.contains("wind") {
            return "wind"
        } else {
            return "sun.max.fill"
        }
    }
    
    var temperatureColor: String {
        if temperature >= 80 {
            return "#FF6B6B" // Hot - Red
        } else if temperature >= 70 {
            return "#FFD93D" // Warm - Yellow
        } else if temperature >= 50 {
            return "#6BCF7F" // Mild - Green
        } else if temperature >= 32 {
            return "#4ECDC4" // Cool - Cyan
        } else {
            return "#A8E6CF" // Cold - Light Blue
        }
    }
}

struct OpenWeatherResponse: Codable {
    let name: String
    let main: MainWeather
    let weather: [WeatherCondition]
}

struct MainWeather: Codable {
    let temp: Double
    let humidity: Int
    let feels_like: Double?
    let temp_min: Double?
    let temp_max: Double?
}

struct WeatherCondition: Codable {
    let main: String
    let description: String
    let icon: String?
}