import SwiftUI

/// Bottom bar: path of the selected node (if one) and selection summary on the
/// left, delete button on the right.
struct BottomBar: View {
    let selectedCount: Int
    let selectedSize: Int64
    let selectedPath: String?
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                if let path = selectedPath {
                    Text(path)
                        .font(.callout)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .help(path)
                }
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Text("Borrar")
            }
            .keyboardShortcut(.delete, modifiers: [.command])
            .disabled(selectedCount == 0)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var summary: String {
        guard selectedCount > 0 else { return "Ningún elemento seleccionado" }
        let noun = selectedCount == 1 ? "seleccionado" : "seleccionados"
        return "\(selectedCount) \(noun) · \(ByteFormatter.string(fromByteCount: selectedSize))"
    }
}
