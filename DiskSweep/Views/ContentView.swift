import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    @EnvironmentObject private var viewModel: DiskSweepViewModel
    @State private var showDeleteConfirm = false
    @State private var isFolderAccessPanelOpen = false

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            content

            Divider()

            BottomBar(
                selectedCount: viewModel.selectedCount,
                selectedSize: viewModel.selectedTotalSize,
                selectedPath: viewModel.selectedPath,
                onDelete: { showDeleteConfirm = true }
            )
        }
        .alert("Delete items?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
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
        .alert(
            "Folder Access",
            isPresented: Binding(
                get: { viewModel.folderAccessError != nil },
                set: { if !$0 { viewModel.folderAccessError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { viewModel.folderAccessError = nil }
        } message: {
            Text(viewModel.folderAccessError ?? "")
        }
        .onChange(of: viewModel.authorizationRequestID) { _ in
            requestDiskAccess()
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
                    Text("Disk")
                        .foregroundStyle(.secondary)
                    Picker("Disk", selection: Binding(
                        get: { viewModel.selectedVolume },
                        set: { viewModel.selectVolume($0) }
                    )) {
                        ForEach(viewModel.volumes) { volume in
                            Text(volume.label).tag(volume)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 220)
                    .disabled(viewModel.isScanning)
                }

                HStack(spacing: 6) {
                    Text("Show >")
                        .foregroundStyle(.secondary)
                    Picker("Threshold", selection: $viewModel.threshold) {
                        ForEach(SizeThreshold.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 110)
                }

                Button(action: scanSelectedVolume) {
                    if viewModel.isScanning {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Scan")
                    }
                }
                .disabled(viewModel.isScanning)
            }

            HStack(spacing: 8) {
                if let usage = viewModel.diskUsage {
                    Text("\(viewModel.selectedVolume.name): \(usage.percentUsed)% used · \(usage.freeFormatted) free of \(usage.totalFormatted)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Button(action: { viewModel.refreshDiskUsage() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh disk space")

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
            placeholder(viewModel.hasFolderAccess
                ? "Press “Scan” to analyze \(viewModel.selectedVolume.name)."
                : "Choose a disk and press “Scan”. DiskSweep will ask for access before scanning.")
        case .scanning where viewModel.rootNodes.isEmpty:
            placeholder("Scanning…")
        case .error(let message):
            placeholder(message)
        default:
            if viewModel.rootNodes.isEmpty {
                placeholder("No items larger than \(viewModel.threshold.label).")
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

    private func scanSelectedVolume() {
        Task { await viewModel.scan() }
    }

    private func requestDiskAccess() {
        guard !isFolderAccessPanelOpen else { return }
        isFolderAccessPanelOpen = true

        let panel = NSOpenPanel()
        panel.title = "Grant DiskSweep Access"
        panel.message = "Select the root of \(viewModel.selectedVolume.name) to grant access for one month."
        panel.prompt = "Grant Access"
        panel.directoryURL = viewModel.selectedVolume.url
        panel.allowedContentTypes = [.folder]
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        panel.begin { response in
            Task { @MainActor in
                isFolderAccessPanelOpen = false
                guard response == .OK, let url = panel.url,
                      viewModel.authorizeFolder(url) else { return }
                scanSelectedVolume()
            }
        }
    }

    // MARK: - Helpers

    private var deleteMessage: String {
        let selected = viewModel.effectiveSelection
        let sizeText = ByteFormatter.string(fromByteCount: viewModel.selectedTotalSize)
        if selected.count == 1, let only = selected.first {
            return "Delete \(only.name) (\(only.formattedSize))? This action cannot be undone."
        }
        return "Delete \(selected.count) items (\(sizeText))? This action cannot be undone."
    }
}
