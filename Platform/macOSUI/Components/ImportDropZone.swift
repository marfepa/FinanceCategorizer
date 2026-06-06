import SwiftUI
import UniformTypeIdentifiers

struct ImportDropZone: View {
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.english
    @Binding var isTargeted: Bool
    let onChooseFile: () -> Void
    let onDroppedURLs: ([URL]) -> Void

    var body: some View {
        VStack(spacing: AppLayoutMetrics.blockGap) {
            Image(systemName: "square.and.arrow.down.on.square")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(AppColors.accent)

            VStack(spacing: AppLayoutMetrics.microGap) {
                Text(LocalizedStringKey("importDropZone.dropHere"))
                    .font(.title2.weight(.semibold))

                Text(LocalizedStringKey("importDropZone.supportedFormats"))
                    .foregroundStyle(.secondary)
            }

            PrimaryButton(title: LocalizedStringKey("Choose File"), action: onChooseFile)

            VStack(spacing: AppLayoutMetrics.microGap) {
                Text(LocalizedStringKey("importDropZone.previewFirst"))
                Text(LocalizedStringKey("importDropZone.advancedMapping"))
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 320)
        .padding(AppLayoutMetrics.heroInset)
        .glassEffect(.regular.interactive(isTargeted), in: RoundedRectangle(cornerRadius: AppRadius.hero))
        .scaleEffect(isTargeted ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isTargeted)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let matchedProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !matchedProviders.isEmpty else {
            return false
        }

        for provider in matchedProviders {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = NSURL(absoluteURLWithDataRepresentation: data, relativeTo: nil) as URL? else {
                    return
                }

                DispatchQueue.main.async {
                    onDroppedURLs([url])
                }
            }
        }

        return true
    }
}
