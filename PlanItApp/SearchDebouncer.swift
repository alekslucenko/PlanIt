import SwiftUI
import Combine

/// A utility class to debounce search input to avoid excessive API calls
class SearchDebouncer: ObservableObject {
    @Published var searchText = ""
    @Published var debouncedSearchText = ""
    
    private var cancellables = Set<AnyCancellable>()
    private let debounceTime: DispatchQueue.SchedulerTimeType.Stride
    
    init(debounceTime: DispatchQueue.SchedulerTimeType.Stride = .milliseconds(500)) {
        self.debounceTime = debounceTime
        
        // Set up debouncing
        $searchText
            .debounce(for: debounceTime, scheduler: DispatchQueue.main)
            .removeDuplicates()
            .assign(to: \.debouncedSearchText, on: self)
            .store(in: &cancellables)
    }
    
    /// Clear search text
    func clear() {
        searchText = ""
    }
    
    /// Set search text programmatically
    func setSearchText(_ text: String) {
        searchText = text
    }
} 