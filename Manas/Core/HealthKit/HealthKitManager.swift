import HealthKit
import Combine

@MainActor
final class HealthKitManager: ObservableObject {
    private let store = HKHealthStore()

    @Published var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published var latestSnapshot: BiometricSnapshot?
    @Published var error: Error?

    private let readTypes: Set<HKObjectType> = [
        HKQuantityType(.heartRate),
        HKQuantityType(.heartRateVariabilitySDNN),
        HKQuantityType(.restingHeartRate),
        HKQuantityType(.stepCount),
        HKQuantityType(.activeEnergyBurned),
        HKCategoryType(.sleepAnalysis)
    ]

    enum AuthorizationStatus {
        case notDetermined, authorized, denied
    }

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationStatus = .denied
            return
        }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            authorizationStatus = .authorized
            await enableBackgroundDelivery()
            await fetchLatestSnapshot()
        } catch {
            self.error = error
            authorizationStatus = .denied
        }
    }

    func fetchLatestSnapshot() async {
        async let heartRate = fetchLatestQuantity(.heartRate, unit: .count().unitDivided(by: .minute()))
        async let hrv = fetchLatestQuantity(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli))
        async let restingHR = fetchLatestQuantity(.restingHeartRate, unit: .count().unitDivided(by: .minute()))
        async let steps = fetchTodaySteps()
        async let sleep = fetchLastNightSleep()

        let (hr, hrvValue, rhr, stepCount, sleepHours) = await (heartRate, hrv, restingHR, steps, sleep)

        latestSnapshot = BiometricSnapshot(
            heartRate: hr,
            hrv: hrvValue,
            restingHeartRate: rhr,
            sleepHours: sleepHours,
            stepCount: stepCount
        )
    }

    private func enableBackgroundDelivery() async {
        let types: [HKQuantityTypeIdentifier] = [.heartRate, .heartRateVariabilitySDNN, .restingHeartRate]
        for typeId in types {
            let type = HKQuantityType(typeId)
            do {
                try await store.enableBackgroundDelivery(for: type, frequency: .hourly)
            } catch {
                // Background delivery is best-effort; non-fatal
            }
        }
    }

    private func fetchLatestQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        let type = HKQuantityType(identifier)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func fetchTodaySteps() async -> Int? {
        let type = HKQuantityType(.stepCount)
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                let value = stats?.sumQuantity()?.doubleValue(for: .count())
                continuation.resume(returning: value.map { Int($0) })
            }
            store.execute(query)
        }
    }

    private func fetchLastNightSleep() async -> Double? {
        let type = HKCategoryType(.sleepAnalysis)
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!
        let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: Date())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: nil)
                    return
                }
                let asleepSamples = samples.filter {
                    $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                }
                let totalSeconds = asleepSamples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                continuation.resume(returning: totalSeconds > 0 ? totalSeconds / 3600.0 : nil)
            }
            store.execute(query)
        }
    }
}
