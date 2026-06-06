import Foundation

struct DateResolver {
    func resolve(bookingDate: Date, valueDate: Date?) -> (bookingDate: Date, valueDate: Date?) {
        (Calendar.current.startOfDay(for: bookingDate), valueDate.map { Calendar.current.startOfDay(for: $0) })
    }
}
