import Foundation

struct ColumnMappingService {
    func defaultMapping() -> [String: String] {
        [
            "date": "bookingDate",
            "concept": "concept",
            "amount": "amount"
        ]
    }
}
