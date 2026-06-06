import Foundation

struct SantanderPDFStrategy: PDFBankStrategy {
    var bankName: String { "Santander" }
    
    func matches(fullText: String) -> Double {
        return 0.0
    }
    
    func extractTransactions(from rawLines: [String]) -> [RawPDFTransaction] {
        return []
    }
}

struct BBVAPDFStrategy: PDFBankStrategy {
    var bankName: String { "BBVA" }
    
    func matches(fullText: String) -> Double {
        return 0.0
    }
    
    func extractTransactions(from rawLines: [String]) -> [RawPDFTransaction] {
        return []
    }
}
