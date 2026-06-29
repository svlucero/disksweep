import SwiftUI

/// A single row in the item list: checkbox · name · parent path · size.
struct ItemRow: View {
    let item: DiskItem
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Toggle(isOn: Binding(get: { item.isSelected }, set: { _ in onToggle() })) {
                EmptyView()
            }
            .labelsHidden()
            .toggleStyle(.checkbox)

            Text(item.name)
                .lineLimit(1)
                .truncationMode(.middle)

            Text(item.parentLabel)
                .foregroundStyle(.secondary)
                .font(.callout)
                .lineLimit(1)

            Spacer(minLength: 12)

            Text(item.formattedSize)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }
}
