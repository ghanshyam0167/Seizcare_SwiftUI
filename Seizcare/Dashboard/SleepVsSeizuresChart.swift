private func alignedData(
    records: [SeizureRecord],
    sleep: [SleepData],
    range: TimeFrameRange
) -> [TimePoint] {
    let cal = Calendar.current
    let now = Date()
    
    switch range {
    case .daily:
        return []
        
    case .weekly:
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        comps.weekday = 2 // Monday
        guard let startOfMonday = cal.date(from: comps) else { return [] }
        
        return (0..<7).compactMap { dayOffset -> TimePoint? in
            guard let start = cal.date(byAdding: .day, value: dayOffset, to: startOfMonday),
                  let end = cal.date(byAdding: .day, value: 1, to: start) else { return nil }
            
            let sCount = records.filter { $0.startTime >= start && $0.startTime < end }.count
            let sHours = sleep.first { cal.isDate($0.date, inSameDayAs: start) }?.hours
            
            return TimePoint(date: start, sleepValue: sHours, seizureCount: sCount)
        }
        
    case .monthly:
        let comps = cal.dateComponents([.year, .month], from: now)
        guard let startOfMonth = cal.date(from: comps),
              let daysRange = cal.range(of: .day, in: .month, for: startOfMonth) else { return [] }
        
        return (0..<daysRange.count).compactMap { dayOffset -> TimePoint? in
            guard let start = cal.date(byAdding: .day, value: dayOffset, to: startOfMonth),
                  let end = cal.date(byAdding: .day, value: 1, to: start) else { return nil }
            
            let sCount = records.filter { $0.startTime >= start && $0.startTime < end }.count
            let sHours = sleep.first { cal.isDate($0.date, inSameDayAs: start) }?.hours
            
            return TimePoint(date: start, sleepValue: sHours, seizureCount: sCount)
        }
        
    case .yearly:
        let year = cal.component(.year, from: now)
        guard let startOfYear = cal.date(from: DateComponents(year: year, month: 1, day: 1)) else { return [] }
        
        return (0..<12).compactMap { monthOffset -> TimePoint? in
            guard let start = cal.date(byAdding: .month, value: monthOffset, to: startOfYear),
                  let end = cal.date(byAdding: .month, value: 1, to: start) else { return nil }
            
            let sCount = records.filter { $0.startTime >= start && $0.startTime < end }.count
            
            let monthSleeps = sleep.filter { $0.date >= start && $0.date < end }
            let avgSleep: Double? = monthSleeps.isEmpty
                ? nil
                : monthSleeps.reduce(0.0) { $0 + $1.hours } / Double(monthSleeps.count)
            
            return TimePoint(date: start, sleepValue: avgSleep, seizureCount: sCount)
        }
    }
}