import SwiftUI
import SharedSettingsKit
#if canImport(UIKit)
import UIKit
#endif

struct DiagnosticsView: View {
    @State private var report: DiagnosticsService.Report? = nil
    @State private var showingCopiedToast = false

    private let diagnosticsService = DiagnosticsService()

    var body: some View {
        List {
            if let report {
                Section {
                    HStack {
                        Text(String(localized: "Bundle Identifier"))
                        Spacer()
                        Text(report.bundleIdentifier)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text(String(localized: "Version & Build"))
                        Spacer()
                        Text("\(report.appVersion) (\(report.buildNumber))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text(String(localized: "App Group Container"))
                        Spacer()
                        if report.isAppGroupAccessible {
                            Text(String(localized: "Accessible"))
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.green)
                        } else {
                            Text(String(localized: "Not Mounted"))
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.orange)
                        }
                    }

                    HStack {
                        Text(String(localized: "App Group Identifier"))
                        Spacer()
                        Text(report.appGroupIdentifier)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text(String(localized: "Keychain Access Group"))
                        Spacer()
                        Text(report.keychainAccessGroup)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text(String(localized: "Schema Version"))
                        Spacer()
                        Text("v\(report.schemaVersion)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(String(localized: "Environment & Identity"))
                } footer: {
                    Text(String(localized: "Diagnostics inspect runtime container availability. Secrets are never displayed or stored in diagnostics."))
                }

                Section {
                    ForEach(report.configuredProviders.sorted(by: { $0.key < $1.key }), id: \.key) { key, isConfigured in
                        let descriptor = ProviderRegistry.shared.descriptor(for: ProviderIdentifier(rawValue: key))
                        HStack {
                            Text(descriptor?.displayName ?? key)
                            Spacer()
                            if isConfigured {
                                Text(String(localized: "Yes"))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.green)
                            } else {
                                Text(String(localized: "No"))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text(String(localized: "Provider Configuration Presence"))
                }

                Section {
                    Button {
                        copyReportToClipboard(report)
                    } label: {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text(showingCopiedToast ? String(localized: "Report Copied") : String(localized: "Copy Diagnostics Report"))
                        }
                    }
                } footer: {
                    Text(String(localized: "This report strictly contains non-sensitive environment metadata and safe presence indicators suitable for integration debugging."))
                }
            } else {
                ProgressView(String(localized: "Testing..."))
            }
        }
        .navigationTitle(String(localized: "Developer Diagnostics"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            report = diagnosticsService.generateReport()
        }
    }

    private func copyReportToClipboard(_ report: DiagnosticsService.Report) {
        #if canImport(UIKit)
        UIPasteboard.general.string = report.formattedText()
        withAnimation {
            showingCopiedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showingCopiedToast = false
        }
        #endif
    }
}
