import Foundation

struct LocalModelCategoryProfile: Codable {
    var categoryID: UUID
    var sampleCount: Int
    var merchantCounts: [String: Int]
    var tokenCounts: [String: Int]
    var signCounts: [String: Int]
    var amountBucketCounts: [String: Int]
    var recurringCount: Int
}

struct LocalModelProfile: Codable {
    var updatedAt: Date
    var minimumSampleCount: Int
    var categories: [LocalModelCategoryProfile]
}

struct LocalTrainingExample {
    let categoryID: UUID
    let merchant: String?
    let description: String
    let sign: Int
    let amount: Decimal
    let isRecurring: Bool
}

struct LocalModelPrediction {
    let categoryID: UUID
    let confidence: Double
    let reason: String
    let isRecurringCandidate: Bool
}

struct CreateMLTrainer {
    func trainProfile(from examples: [LocalTrainingExample]) -> LocalModelProfile? {
        guard !examples.isEmpty else { return nil }

        var grouped: [UUID: [LocalTrainingExample]] = [:]
        for example in examples {
            grouped[example.categoryID, default: []].append(example)
        }

        let categories = grouped.map { categoryID, categoryExamples in
            var merchantCounts: [String: Int] = [:]
            var tokenCounts: [String: Int] = [:]
            var signCounts: [String: Int] = [:]
            var amountBucketCounts: [String: Int] = [:]
            var recurringCount = 0

            for example in categoryExamples {
                if let merchant = sanitizedMerchant(example.merchant) {
                    merchantCounts[merchant, default: 0] += 1
                }

                for token in tokens(from: example.description) {
                    tokenCounts[token, default: 0] += 1
                }

                signCounts[signKey(example.sign), default: 0] += 1
                amountBucketCounts[amountBucket(for: example.amount), default: 0] += 1
                if example.isRecurring {
                    recurringCount += 1
                }
            }

            return LocalModelCategoryProfile(
                categoryID: categoryID,
                sampleCount: categoryExamples.count,
                merchantCounts: merchantCounts,
                tokenCounts: tokenCounts,
                signCounts: signCounts,
                amountBucketCounts: amountBucketCounts,
                recurringCount: recurringCount
            )
        }
        .sorted { $0.sampleCount > $1.sampleCount }

        return LocalModelProfile(
            updatedAt: .now,
            minimumSampleCount: 2,
            categories: categories
        )
    }

    func predict(input: NormalizedTransactionDTO, profile: LocalModelProfile) -> LocalModelPrediction? {
        let tokens = Set(tokens(from: input.cleanedDescription))
        let merchant = sanitizedMerchant(input.merchantCanonicalName)
        let sign = signKey(input.sign)
        let amountBucket = amountBucket(for: input.amount)

        let scored = profile.categories.compactMap { category -> (LocalModelCategoryProfile, Double, [String])? in
            guard category.sampleCount >= profile.minimumSampleCount else { return nil }

            var score = 0.0
            var reasons: [String] = []

            if let merchant, let merchantHits = category.merchantCounts[merchant] {
                score += Double(merchantHits) * 4.0
                reasons.append("merchant")
            }

            let tokenHits = tokens.reduce(0) { partial, token in
                partial + (category.tokenCounts[token] ?? 0)
            }
            if tokenHits > 0 {
                score += Double(tokenHits) * 0.9
                reasons.append("tokens")
            }

            if let signHits = category.signCounts[sign], signHits > 0 {
                score += Double(signHits) * 0.5
                reasons.append("sign")
            }

            if let bucketHits = category.amountBucketCounts[amountBucket], bucketHits > 0 {
                score += Double(bucketHits) * 0.7
                reasons.append("amount")
            }

            guard score > 0 else { return nil }
            return (category, score, reasons)
        }
        .sorted { $0.1 > $1.1 }

        guard let best = scored.first else { return nil }
        let totalScore = scored.reduce(0.0) { $0 + $1.1 }
        let relativeConfidence = totalScore > 0 ? best.1 / totalScore : 0
        let sampleBoost = min(0.18, Double(best.0.sampleCount) * 0.02)
        let confidence = min(0.97, max(0.55, relativeConfidence + sampleBoost))
        let recurringRatio = best.0.sampleCount > 0 ? Double(best.0.recurringCount) / Double(best.0.sampleCount) : 0

        return LocalModelPrediction(
            categoryID: best.0.categoryID,
            confidence: confidence,
            reason: "Local model matched \(best.2.joined(separator: ", ")) from \(best.0.sampleCount) learned examples.",
            isRecurringCandidate: recurringRatio >= 0.5
        )
    }

    private func sanitizedMerchant(_ merchant: String?) -> String? {
        guard let merchant else {
            return nil
        }

        let normalized = merchant
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !normalized.isEmpty else {
            return nil
        }
        return normalized
    }

    private func tokens(from description: String) -> [String] {
        let normalized = description
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        let rawTokens = normalized.components(separatedBy: CharacterSet.alphanumerics.inverted)
        let stopWords: Set<String> = [
            "sepa", "bizum", "transferencia", "ord", "s", "compra", "recibo", "trf",
            "de", "la", "el", "los", "las", "para", "con", "por"
        ]

        return rawTokens.filter { token in
            token.count >= 3 && !stopWords.contains(token)
        }
    }

    private func signKey(_ sign: Int) -> String {
        sign >= 0 ? "income" : "expense"
    }

    private func amountBucket(for amount: Decimal) -> String {
        let absolute = abs(NSDecimalNumber(decimal: amount).doubleValue)
        switch absolute {
        case ..<20: return "0-20"
        case ..<50: return "20-50"
        case ..<100: return "50-100"
        case ..<250: return "100-250"
        case ..<1000: return "250-1000"
        default: return "1000+"
        }
    }
}
