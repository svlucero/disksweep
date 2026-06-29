import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: DiskSweepViewModel
    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            content

            Divider()

            BottomBar(
                selectedCount: viewModel.selectedCount,
                selectedSize: viewModel.selectedTotalSize,
                onDelete: { showDeleteConfirm = true }
            )
        }
        .alert("¿Borrar elementos?", isPresented: $showDeleteConfirm) {
            Button("Cancelar", role: .cancel) {}
            Button("Borrar", role: .destructive) {
                viewModel.deleteSelected()
            }
        } message: {
            Text(deleteMessage)
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { viewModel.deleteError != nil },
                set: { if !$0 { viewModel.deleteError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { viewModel.deleteError = nil }
        } message: {
            Text(viewModel.deleteError ?? "")
        }
    }

    // MARK: - Header / toolbar

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text("DiskSweep")
                    .font(.title2.bold())

                Spacer()

                HStack(spacing: 6) {
                    Text("Mostrar >")
                        .foregroundStyle(.secondary)
                    Picker("Umbral", selection: $viewModel.threshold) {
                        ForEach(SizeThreshold.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 110)
                }

                Button(action: { Task { await viewModel.scan() } }) {
                    if viewModel.isScanning {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Escanear")
                    }
                }
                .disabled(viewModel.isScanning)
            }

            HStack(spacing: 12) {
                if let usage = viewModel.diskUsage {
                    Text("Disco: \(usage.percentUsed)% usado · \(usage.freeFormatted) libres")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                if viewModel.isScanning {
                    ProgressView(value: viewModel.scanProgress)
                        .frame(maxWidth: 160)
                }
            }
        }
        .padding()
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch viewModel.scanState {
        case .idle:
            placeholder("Pulsá «Escanear» para analizar tu carpeta personal.")
        case .scanning where viewModel.rootNodes.isEmpty:
            placeholder("Escaneando…")
        case .error(let message):
            placeholder(message)
        default:
            if viewModel.rootNodes.isEmpty {
                placeholder("No hay elementos por encima de \(viewModel.threshold.label).")
            } else {
                tree
            }
        }
    }

    private var tree: some View {
        // `revision` is read so the list re-renders when nodes expand or load.
        let _ = viewModel.revision
        return List(selection: $viewModel.selection) {
            ForEach(viewModel.visibleNodes) { node in
                NodeRow(node: node) {
                    Task { await viewModel.toggleExpand(node) }
                }
                .tag(node.id)
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    private func placeholder(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private var deleteMessage: String {
        let selected = viewModel.effectiveSelection
        let sizeText = ByteFormatter.string(fromByteCount: viewModel.selectedTotalSize)
        if selected.count == 1, let only = selected.first {
            return "¿Borrar \(only.name) (\(only.formattedSize))? Esta acción no se puede deshacer."
        }
        return "¿Borrar \(selected.count) elementos (\(sizeText))? Esta acción no se puede deshacer."
    }
}
