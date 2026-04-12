import SwiftUI

struct DebugPanel: View {
    let selectedDevice: CameraDeviceDescriptor?
    let connectionState: AppViewModel.ConnectionState
    let previewSummary: String
    let controlsSummary: String
    let backendSummary: String
    let capabilitySourceSummary: String
    let rawMappingSummary: String
    let pipelineSummary: String
    let rawTargetSummary: String
    let capabilities: [CameraControlCapability]
    let currentValues: [CameraControlKey: CameraControlValue]
    let entries: [DebugStore.Entry]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Diagnostics")
                .font(.headline)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    summarySection
                    capabilitiesSection
                    logSection
                }
            }
            .frame(maxHeight: 240)
        }
        .padding(12)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Device")
                .font(.subheadline.weight(.semibold))
            Text("Name: \(selectedDevice?.name ?? "None")")
            Text("AVFoundation ID: \(selectedDevice?.avFoundationUniqueID ?? "n/a")")
                .foregroundStyle(.secondary)
            Text("Backend ID: \(selectedDevice?.backendIdentifier ?? "n/a")")
                .foregroundStyle(.secondary)
            Text("USB: \(selectedDevice?.usbIdentitySummary ?? "n/a")")
                .foregroundStyle(.secondary)
            Text("Serial: \(selectedDevice?.serialNumber ?? "n/a")")
                .foregroundStyle(.secondary)
            Text("Connection: \(connectionLabel)")
                .foregroundStyle(.secondary)
            Text("Preview: \(previewSummary)")
                .foregroundStyle(.secondary)
            Text("Controls: \(controlsSummary)")
                .foregroundStyle(.secondary)
            Text("Backend: \(backendSummary)")
                .foregroundStyle(.secondary)
            Text("Sources: \(capabilitySourceSummary)")
                .foregroundStyle(.secondary)
            Text("Mappings: \(rawMappingSummary)")
                .foregroundStyle(.secondary)
            Text("Pipeline: \(pipelineSummary)")
                .foregroundStyle(.secondary)
            Text("Raw Target: \(rawTargetSummary)")
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }

    private var capabilitiesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Capabilities")
                .font(.subheadline.weight(.semibold))
            ForEach(capabilities.prefix(8)) { capability in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(capability.displayName) • source=\(capability.source.rawValue) • supported=\(capability.isSupported ? "yes" : "no") • readable=\(capability.isReadable ? "yes" : "no") • writable=\(capability.isWritable ? "yes" : "no")")
                    Text("Current: \(formattedValue(currentValues[capability.key] ?? capability.currentValue))")
                        .foregroundStyle(.secondary)
                    Text("Range: \(formattedValue(capability.minValue)) ... \(formattedValue(capability.maxValue)) • step \(formattedValue(capability.stepValue))")
                        .foregroundStyle(.secondary)
                    if capability.enumOptions.isEmpty == false {
                        Text("Options: \(capability.enumOptions.map(\.value).joined(separator: ", "))")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
            }
            if capabilities.count > 8 {
                Text("Showing 8 of \(capabilities.count) capabilities")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent Activity")
                .font(.subheadline.weight(.semibold))
            ForEach(entries.prefix(12)) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text("[\(entry.category)] \(entry.message)")
                    Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func formattedValue(_ value: CameraControlValue?) -> String {
        switch value {
        case let .bool(boolValue):
            boolValue ? "true" : "false"
        case let .int(intValue):
            "\(intValue)"
        case let .double(doubleValue):
            doubleValue.formatted(.number.precision(.fractionLength(2)))
        case let .enumCase(enumValue):
            enumValue
        case nil:
            "n/a"
        }
    }

    private var connectionLabel: String {
        switch connectionState {
        case .loading:
            "Loading"
        case .connected:
            "Connected"
        case .disconnected:
            "Disconnected"
        case .deviceBusy:
            "Device Busy"
        case .partialControlAccess:
            "Partial Access"
        }
    }
}
