import SwiftUI

/// A single row in the file tree: indentation · disclosure chevron · icon ·
/// name · size. Selection is handled by the enclosing `List` (click the row).
struct NodeRow: View {
    @ObservedObject var node: FileNode
    let onToggleExpand: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            // Indentation proportional to tree depth.
            Color.clear.frame(width: CGFloat(node.depth) * 16, height: 1)

            // Disclosure chevron (directories only).
            if node.isDirectory {
                Button(action: onToggleExpand) {
                    Image(systemName: node.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 14)
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 14, height: 1)
            }

            Image(systemName: node.isDirectory ? "folder.fill" : "doc")
                .foregroundStyle(node.isDirectory ? Color.accentColor : Color.secondary)
                .frame(width: 16)

            Text(node.name)
                .lineLimit(1)
                .truncationMode(.middle)

            if node.isLoading {
                ProgressView().controlSize(.small)
            }

            Spacer(minLength: 8)

            Text(node.formattedSize)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
