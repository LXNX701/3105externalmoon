import SwiftUI
import UniformTypeIdentifiers

/// Menú principal de Moon Place tras iniciar sesión.
/// Muestra dos apartados: MoonV1 (opciones propias, por ahora importables)
/// y MoonV2 (opciones ya hechas, incluidas dentro de la app).
struct MoonPlaceView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var auth: MoonAuthManager

    @StateObject private var store = PatchProjectStore()
    @State private var section: MoonSection = .moonV2
    @State private var showWelcomeBadge = true

    enum MoonSection: String, CaseIterable, Identifiable {
        case moonV1 = "MoonV1"
        case moonV2 = "MoonV2"
        var id: String { rawValue }
    }

    /// Catálogo de parches incluidos en la app (carpeta moonplace/MoonV2Patches).
    /// Para añadir más opciones más adelante: copia el .3105 a esa carpeta,
    /// añádelo en project.pbxproj (Resources) y agrégalo a esta lista.
    static let bundledMoonV2Patches: [(resource: String, name: String)] = [
        ("MOON_FFTH_ANTENA_0", "FFTH - Antena 1"),
        ("MOON_FFTH_ANTENA_1", "FFTH - Antena 2"),
        ("MOON_FFTH_ANTENA_2", "FFTH - Antena 3"),
        ("MOON_FFTH_ANTENA_3", "FFTH - Antena 4"),
        ("MOON_FFTH_SIN_ANTENA_0", "FFTH - Sin antena 1"),
        ("MOON_FFTH_SIN_ANTENA_1", "FFTH - Sin antena 2"),
        ("MOON_FFTH_SIN_ANTENA_2", "FFTH - Sin antena 3"),
        ("MOON_FFTH_SIN_ANTENA_3", "FFTH - Sin antena 4"),
        ("MOON_FFMAX_ANTENA_0", "FFMAX - Antena 1"),
        ("MOON_FFMAX_ANTENA_1", "FFMAX - Antena 2"),
        ("MOON_FFMAX_ANTENA_2", "FFMAX - Antena 3"),
        ("MOON_FFMAX_ANTENA_3", "FFMAX - Antena 4"),
        ("MOON_FFMAX_SIN_ANTENA_0", "FFMAX - Sin antena 1"),
        ("MOON_FFMAX_SIN_ANTENA_1", "FFMAX - Sin antena 2"),
        ("MOON_FFMAX_SIN_ANTENA_2", "FFMAX - Sin antena 3"),
        ("MOON_FFMAX_SIN_ANTENA_3", "FFMAX - Sin antena 4"),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ExploitStatusHeader(appState: appState)
                Divider()

                Picker("", selection: $section) {
                    ForEach(MoonSection.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 10)

                switch section {
                case .moonV1:
                    MoonV1Section(store: store)
                case .moonV2:
                    MoonV2Section(store: store)
                }
            }
            .navigationTitle("Moon Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showWelcomeBadge = true
                        } label: {
                            Label("Welcome message", systemImage: "sparkles")
                        }
                        Button(role: .destructive) {
                            auth.logout()
                        } label: {
                            Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                }
            }
            .overlay(alignment: .top) {
                if showWelcomeBadge, let user = auth.username {
                    welcomeBadge(user)
                        .padding(.top, 6)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .alert(item: $store.alert) { alert in
                Alert(
                    title: Text(alert.titleKey == "common.done" ? "Done" : "Failed"),
                    message: Text(alert.message(language: .english)),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onAppear {
                appState.detectSupport()
                if auth.justWelcomed {
                    auth.justWelcomed = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation { showWelcomeBadge = false }
                    }
                } else {
                    showWelcomeBadge = false
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Color.indigo)
    }

    private func welcomeBadge(_ user: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "moon.stars.fill")
            Text("Welcome to Moon Place, \(user)")
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Capsule().fill(.ultraThinMaterial))
    }
}

// MARK: - Cabecera de estado del exploit

private struct ExploitStatusHeader: View {
    @ObservedObject var appState: AppState

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.footnote.weight(.medium))
            Spacer()
            if !appState.exploitStatus.isSuccess {
                Button("Activate") {
                    appState.runKernelExploitIfNeeded()
                }
                .font(.footnote.bold())
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var color: Color {
        if appState.kernelExploitRunning { return .yellow }
        if appState.exploitStatus.isSuccess { return .green }
        if case .failed = appState.exploitStatus { return .red }
        return .gray
    }

    private var label: String {
        if appState.kernelExploitRunning { return "Activating full access…" }
        if appState.exploitStatus.isSuccess {
            return "Full access active — patches ready"
        }
        if case .failed = appState.exploitStatus {
            return "Activation failed — relaunch the app and retry"
        }
        if case .unsupported(let reason) = appState.exploitStatus {
            return "Not supported on \(reason)"
        }
        return "Tap Activate before applying patches"
    }
}

// MARK: - MoonV1

private struct MoonV1Section: View {
    @ObservedObject var store: PatchProjectStore
    @State private var showImporter = false

    var body: some View {
        List {
            Section {
                if store.items.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "moonphase.new.moon")
                            .font(.system(size: 42, weight: .light))
                            .foregroundStyle(Color.indigo)
                        Text("MoonV1")
                            .font(.headline)
                        Text("Options for MoonV1 are coming soon. You can already import your own .3105 options created with 3105.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(store.items) { item in
                        MoonPatchRow(item: item, store: store)
                    }
                }
            } header: {
                Text("My options")
            } footer: {
                Text("Each option includes Apply and Restore Originals.")
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { store.reload() }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showImporter = true
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .disabled(store.isBusy)
            }
        }
        .sheet(isPresented: $showImporter) {
            FileDocumentPicker(
                allowedContentTypes: [UTType(filenameExtension: "3105") ?? .data, .data],
                copiesSelectedDocument: true,
                allowsMultipleSelection: false,
                onSelection: { result in
                    showImporter = false
                    if case .success(let urls) = result, let url = urls.first {
                        store.importPackage(at: url)
                    }
                },
                onCancel: { showImporter = false }
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - MoonV2

private struct MoonV2Section: View {
    @ObservedObject var store: PatchProjectStore
    @State private var family = "FFTH"
    @State private var antenna = "ANTENA"

    /// Nombres de recursos ya instalados en la librería (persistido).
    @AppStorage("moon.v2.installedPatches") private var installedPatchesRaw = ""

    private var installedSet: Set<String> {
        Set(installedPatchesRaw.split(separator: "\n").map(String.init))
    }

    var body: some View {
        List {
            Section {
                Picker("Familia", selection: $family) {
                    Text("FFTH").tag("FFTH")
                    Text("FFMAX").tag("FFMAX")
                }
                .pickerStyle(.segmented)
                Picker("Antena", selection: $antenna) {
                    Text("Con antena").tag("ANTENA")
                    Text("Sin antena").tag("SIN_ANTENA")
                }
                .pickerStyle(.segmented)
            }
            Section {
                ForEach(filteredEntries, id: \.resource) { entry in
                    bundledRow(entry)
                    private var filteredEntries: [(resource: String, name: String)] {
                        MoonPlaceView.bundledMoonV2Patches.filter { entry in
                            entry.resource.contains("_\(family)_") && entry.resource.contains("_\(antenna)_")
                        }
                    }
                }
            } header: {
                Text("MoonV2 options")
            } footer: {
                Text("Ready-made options. Tap Install once, then Apply. Restore Originals undoes any applied option.")
            }

            if !store.items.isEmpty {
                Section {
                    ForEach(store.items) { item in
                        MoonPatchRow(item: item, store: store)
                    }
                } header: {
                    Text("Installed patches")
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { store.reload() }
    }

    @ViewBuilder
    private func bundledRow(_ entry: (resource: String, name: String)) -> some View {
        let isInstalled = installedSet.contains(entry.resource)
        HStack(spacing: 12) {
            Image(systemName: "shippingbox.fill")
                .foregroundStyle(Color.indigo)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.body.weight(.semibold))
                Text(isInstalled ? "Installed" : "Ready to install")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if store.isBusy {
                ProgressView().controlSize(.small)
            } else if !isInstalled {
                Button("Install") {
                    install(entry)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }

    private func install(_ entry: (resource: String, name: String)) {
        guard let url = Bundle.main.url(
            forResource: entry.resource,
            withExtension: "3105"
        ) else {
            store.alert = PatchStoreAlert(
                titleKey: "common.failed",
                messageKey: "patch.error.unsupported_format"
            )
            return
        }
        markInstalled(entry.resource)
        store.importPackage(at: url)
    }

    private func markInstalled(_ resource: String) {
        var set = installedSet
        set.insert(resource)
        installedPatchesRaw = set.joined(separator: "\n")
    }
}

// MARK: - Fila de parche instalado (Apply / Restore Originals)

private struct MoonPatchRow: View {
    let item: PatchLibraryItem
    @ObservedObject var store: PatchProjectStore

    @State private var isWorking = false
    @State private var showApplyConfirm = false
    @State private var showRestoreConfirm = false
    @State private var resultAlert: PatchStoreAlert?

    private var receipt: PatchTransactionReceipt? {
        DevicePatchService.latestReceipt(projectID: item.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: item.isLocked ? "lock.doc.fill" : "moon.zzz.fill")
                    .foregroundStyle(Color.indigo)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.project?.name ?? "Locked patch")
                        .font(.body.weight(.semibold))
                    if !item.isLocked {
                        Text(receipt != nil ? "Applied — original files backed up" : "Not applied")
                            .font(.caption)
                            .foregroundStyle(receipt != nil ? .green : .secondary)
                    }
                }
                Spacer()
                if isWorking {
                    ProgressView().controlSize(.small)
                }
            }

            if item.isLocked {
                Text("This patch is password protected. Unlock it from the original 3105 Patches section.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 10) {
                    Button {
                        showApplyConfirm = true
                    } label: {
                        Label("Apply", systemImage: "checkmark.shield.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isWorking || store.isBusy)

                    Button(role: .destructive) {
                        showRestoreConfirm = true
                    } label: {
                        Label("Restore Originals", systemImage: "arrow.uturn.backward.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .disabled(isWorking || store.isBusy || receipt == nil)
                }
                .controlSize(.small)
            }
        }
        .padding(.vertical, 6)
        .confirmationDialog(
            "Apply this patch?",
            isPresented: $showApplyConfirm,
            titleVisibility: .visible
        ) {
            Button("Apply") { apply() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The original files are backed up automatically so you can restore them later.")
        }
        .confirmationDialog(
            "Restore original files?",
            isPresented: $showRestoreConfirm,
            titleVisibility: .visible
        ) {
            Button("Restore Originals", role: .destructive) { restore() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This undoes the patch and puts the original files back.")
        }
        .alert(item: $resultAlert) { alert in
            Alert(
                title: Text(alert.titleKey == "common.done" ? "Done" : "Failed"),
                message: Text(alert.message(language: .english)),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func apply() {
        guard let baseProject = item.project else { return }
        isWorking = true
        Task.detached(priority: .userInitiated) {
            do {
                let project = item.summary.schemaVersion >= 2
                    ? try PatchProjectLibrary.synchronizeWorkspace(item: item)
                    : baseProject
                _ = try DevicePatchService.apply(project: project)
                await MainActor.run {
                    store.reload()
                    isWorking = false
                    resultAlert = PatchStoreAlert(
                        titleKey: "common.done",
                        messageKey: "patch.applied_message"
                    )
                }
            } catch let error as PatchPackageError {
                await MainActor.run {
                    isWorking = false
                    resultAlert = PatchStoreAlert(
                        titleKey: "common.failed",
                        messageKey: error.localizationKey,
                        messageArgument: error.localizationArgument
                    )
                }
            } catch {
                await MainActor.run {
                    isWorking = false
                    resultAlert = PatchStoreAlert(
                        titleKey: "common.failed",
                        messageKey: "patch.error.apply"
                    )
                }
            }
        }
    }

    private func restore() {
        guard let receipt else { return }
        isWorking = true
        Task.detached(priority: .userInitiated) {
            do {
                try DevicePatchService.restore(receipt: receipt)
                await MainActor.run {
                    store.reload()
                    isWorking = false
                    resultAlert = PatchStoreAlert(
                        titleKey: "common.done",
                        messageKey: "patch.restored_message"
                    )
                }
            } catch let error as PatchPackageError {
                await MainActor.run {
                    isWorking = false
                    resultAlert = PatchStoreAlert(
                        titleKey: "common.failed",
                        messageKey: error.localizationKey,
                        messageArgument: error.localizationArgument
                    )
                }
            } catch {
                await MainActor.run {
                    isWorking = false
                    resultAlert = PatchStoreAlert(
                        titleKey: "common.failed",
                        messageKey: "patch.error.restore"
                    )
                }
            }
        }
    }
}
