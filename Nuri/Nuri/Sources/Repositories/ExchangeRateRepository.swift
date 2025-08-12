import Foundation

protocol ExchangeRateRepositoryType {
    func getExchangeRate(currency: String) async -> Double?
    func getCachedExchangeRate(currency: String) -> Double?
    func startPeriodicUpdates(currency: String, interval: TimeInterval, onUpdate: @escaping (Double) -> Void)
    func stopPeriodicUpdates()
}

final class ExchangeRateRepository: ExchangeRateRepositoryType {
    
    // MARK: - Properties
    
    private let cacheKeyPrefix = "nuri.exchangeRate"
    private let timestampKeyPrefix = "nuri.exchangeRate.timestamp"
    private let cacheValidityDuration: TimeInterval = 300 // 5 minutes
    private var updateTimer: Timer?
    
    // MARK: - Public Methods
    
    func getExchangeRate(currency: String) async -> Double? {
        print("🔄 [ExchangeRateRepository] Fetching exchange rate for \(currency)...")
        
        guard let url = URL(string: "https://mempool.space/api/v1/prices") else {
            print("❌ [ExchangeRateRepository] Invalid URL for price API")
            return nil
        }
        
        do {
            let startTime = Date()
            let (data, response) = try await URLSession.shared.data(from: url)
            let fetchTime = Date().timeIntervalSince(startTime)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🔄 [ExchangeRateRepository] API Response: \(httpResponse.statusCode) in \(String(format: "%.2f", fetchTime))s")
            }
            
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let rate = dict[currency.uppercased()] as? Double {
                print("🔄 [ExchangeRateRepository] ✅ Fetched \(currency) rate: \(rate)")
                cacheExchangeRate(rate, for: currency)
                return rate
            } else {
                print("❌ [ExchangeRateRepository] Failed to parse \(currency) rate from response")
            }
        } catch {
            print("❌ [ExchangeRateRepository] Price fetch failed: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    func getCachedExchangeRate(currency: String) -> Double? {
        let cacheKey = "\(cacheKeyPrefix).\(currency.lowercased())"
        let timestampKey = "\(timestampKeyPrefix).\(currency.lowercased())"
        
        let cachedRate = UserDefaults.standard.double(forKey: cacheKey)
        let cachedTimestamp = UserDefaults.standard.object(forKey: timestampKey) as? Date ?? Date.distantPast
        
        let cacheAge = Date().timeIntervalSince(cachedTimestamp)
        let isStale = cacheAge >= cacheValidityDuration
        
        if cachedRate > 0 {
            print("💱 [ExchangeRateRepository] Loaded cached \(currency) rate: \(cachedRate)")
            print("💱 [ExchangeRateRepository]   Cache age: \(Int(cacheAge))s, is stale: \(isStale)")
            return cachedRate
        }
        
        print("⚠️ [ExchangeRateRepository] No cached \(currency) rate found")
        return nil
    }
    
    func startPeriodicUpdates(currency: String, interval: TimeInterval, onUpdate: @escaping (Double) -> Void) {
        stopPeriodicUpdates()
        
        print("⏰ [ExchangeRateRepository] Starting periodic updates every \(Int(interval))s")
        updateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task {
                if let rate = await self.getExchangeRate(currency: currency) {
                    await MainActor.run {
                        onUpdate(rate)
                    }
                }
            }
        }
    }
    
    func stopPeriodicUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
        print("⏰ [ExchangeRateRepository] Stopped periodic updates")
    }
    
    // MARK: - Private Methods
    
    private func cacheExchangeRate(_ rate: Double, for currency: String) {
        let cacheKey = "\(cacheKeyPrefix).\(currency.lowercased())"
        let timestampKey = "\(timestampKeyPrefix).\(currency.lowercased())"
        
        UserDefaults.standard.set(rate, forKey: cacheKey)
        UserDefaults.standard.set(Date(), forKey: timestampKey)
        print("💱 [ExchangeRateRepository] Cached \(currency) rate: \(rate)")
    }
    
    deinit {
        stopPeriodicUpdates()
    }
}