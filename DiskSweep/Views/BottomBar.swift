import SwiftUI

/// Bottom bar: selection summary on the left, delete button on the right.
struct BottomBar: View {
    let selectedCount: Int
    let selectedSize: Int64
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Text(summary)
                .foregroundStyle(.secondary)

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Text("Borrar")
            }
            .keyboardShortcut(.delete, modifiers: [.command])
            .disabled(selectedCount == 0)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var summary: String {
        guard selectedCount > 0 else { return "Ningún elemento seleccionado" }
        let noun = selectedCount == 1 ? "seleccionado" : "seleccionados"
        return "\(selectedCount) \(noun) · \(ByteFormatter.string(fromByteCount: selectedSize))"
    }
}
