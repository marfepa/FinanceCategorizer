import Foundation
import CryptoKit
import PDFKit

enum ImportFileFormat {
    case csv
    case xlsx
    case pdf
}

enum FileImportError: LocalizedError {
    case unsupportedFormat
    case unreadableFile

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "This importer currently supports .csv, .xlsx, and .pdf bank exports."
        case .unreadableFile:
            return "The selected file could not be read."
        }
    }
}

struct FileImportService {
    func supportedFileExtensions() -> [String] {
        ["csv", "xlsx", "pdf"]
    }

    func canImport(url: URL) -> Bool {
        supportedFileExtensions().contains(url.pathExtension.lowercased())
    }

    func format(for url: URL) throws -> ImportFileFormat {
        switch url.pathExtension.lowercased() {
        case "csv":
            return .csv
        case "xlsx":
            return .xlsx
        case "pdf":
            return .pdf
        default:
            throw FileImportError.unsupportedFormat
        }
    }

    func readText(from url: URL) throws -> String {
        try withAccess(to: url) {
            guard try format(for: url) == .csv else {
                throw FileImportError.unsupportedFormat
            }

            guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                throw FileImportError.unreadableFile
            }

            return text
        }
    }

    func readPDFText(from url: URL) throws -> String {
        try withAccess(to: url) {
            guard try format(for: url) == .pdf else {
                throw FileImportError.unsupportedFormat
            }

            guard let pdf = PDFDocument(url: url) else {
                throw FileImportError.unreadableFile
            }

            var fullText = ""
            for i in 0..<pdf.pageCount {
                if let page = pdf.page(at: i), let text = page.string {
                    fullText += text + "\n"
                }
            }

            if fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw FileImportError.unreadableFile
            }

            return fullText
        }
    }

    func readData(from url: URL) throws -> Data {
        try withAccess(to: url) {
            guard let data = try? Data(contentsOf: url) else {
                throw FileImportError.unreadableFile
            }
            return data
        }
    }

    func fingerprint(for data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func withAccess<T>(to url: URL, perform: () throws -> T) throws -> T {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        return try perform()
    }
}
