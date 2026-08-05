import Foundation

protocol TransactionNormalizing {
    func normalize(_ row: ParsedRowDTO) -> NormalizedTransactionDTO
}
struct TransactionNormalizer: TransactionNormalizing {
    private let descriptionCleaner = DescriptionCleaner()
    private let merchantExtractor = MerchantExtractionService()
    private let merchantCanonicalizer = MerchantCanonicalizer()
    private let amountSignResolver = AmountSignResolver()
    private let kindResolver = TransactionKindResolver()
    private let dateResolver = DateResolver()
    private let fingerprintBuilder = FingerprintBuilder()

    func normalize(_ row: ParsedRowDTO) -> NormalizedTransactionDTO {
        let resolvedDates = dateResolver.resolve(bookingDate: row.bookingDate, valueDate: row.valueDate)
        let cleanedDescription = descriptionCleaner.clean(row.description)
        let extractedMerchant = merchantExtractor.extract(from: cleanedDescription)
        let canonicalMerchant = merchantCanonicalizer.canonicalize(extractedMerchant)
        let sign = amountSignResolver.resolveSign(amount: row.amount, rawDescription: row.description)
        let kind = kindResolver.resolve(
            rawDescription: row.description,
            cleanedDescription: cleanedDescription,
            amount: row.amount
        )
        let fingerprint = fingerprintBuilder.build(
            bookingDate: resolvedDates.bookingDate,
            cleanedDescription: cleanedDescription,
            amount: row.amount,
            currencyCode: row.currencyCode
        )

        return NormalizedTransactionDTO(
            externalID: row.externalID,
            bookingDate: resolvedDates.bookingDate,
            valueDate: resolvedDates.valueDate,
            rawDescription: row.description,
            cleanedDescription: cleanedDescription,
            merchantDisplayName: canonicalMerchant.displayName,
            merchantCanonicalName: canonicalMerchant.canonicalName,
            amount: row.amount,
            balance: row.balance,
            currencyCode: row.currencyCode,
            accountName: row.accountName,
            sign: sign,
            fingerprint: fingerprint,
            kind: kind
        )
    }
}
