import Foundation

/// A raw transaction extracted from a PDF before formal import validation.
struct RawPDFTransaction {
    let dateStr: String
    let valueDateStr: String?
    let concept: String
    let amountStr: String
    let balanceStr: String?
    let rawText: String
}

/// A strategy for extracting transactions from a specific bank's PDF statement format.
protocol PDFBankStrategy {
    /// The canonical name of the bank this strategy supports.
    var bankName: String { get }
    
    /// Returns a heuristic score [0.0 - 1.0] indicating the likelihood that the provided text belongs to this bank.
    func matches(fullText: String) -> Double
    
    /// Parses the raw lines of the PDF into raw transactions.
    func extractTransactions(from rawLines: [String]) -> [RawPDFTransaction]
}
