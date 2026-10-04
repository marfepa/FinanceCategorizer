import Foundation
import SwiftData

/// Proposes transfers between the user's own accounts for review. Nothing is
/// marked automatically; confirmations go through `CorrectionBatchService` so
/// they can be undone.
@MainActor
final class TransferPairService {
    private let modelContainer: ModelContainer
    private let batchService: CorrectionBatchService
    private let detector = TransferPairDetector()
    /// "Not a transfer" answers last for the session only (no schema change).
    private var dismissedKeys: Set<String> = []

    init(modelContainer: ModelContainer, batchService: CorrectionBatchService) {
        self.modelContainer = modelContainer
        self.batchService = batchService
    }

    func proposals() throws -> [TransferPairProposal] {
        let context = ModelContext(modelContainer)
        let candidates = try context.fetch(FetchDescriptor<Transaction>()).map(TransferPairCandidate.init)
        return detector.detect(in: candidates).filter { !dismissedKeys.contains($0.id) }
    }

    @discardableResult
    func confirm(_ proposal: TransferPairProposal) throws -> CorrectionBatch {
        try batchService.markAsTransferPair(outgoingID: proposal.outgoing.id, incomingID: proposal.incoming.id)
    }

    func dismiss(_ proposal: TransferPairProposal) {
        dismissedKeys.insert(proposal.id)
    }
}
