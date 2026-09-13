import Foundation

struct ProfileRecord: Codable, Identifiable, Equatable {

    let id: UUID
    let filename: String
    let name: String?
    let teamID: String?
    let applicationIdentifier: String?
    let notAfter: Date?
    let provisionedDeviceCount: Int?
    let provisionsAllDevices: Bool?
    let getTaskAllow: Bool?
    let addedAt: Date

    var displayName: String {
        name ?? filename
    }
}

@MainActor
final class ProfileStore: ObservableObject {

    @Published private(set) var profiles:
        [ProfileRecord] = []

    @Published var selectedID: UUID?

    private let dir: URL
    private let indexURL: URL

    private struct Index: Codable {

        var profiles:
            [ProfileRecord] = []

        var selectedID:
            UUID?
    }

    init() {

        let base =
            FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0]

        dir =
            base.appendingPathComponent(
                "Profiles",
                isDirectory: true
            )

        try? FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )

        indexURL =
            base.appendingPathComponent(
                "profiles.json"
            )

        load()
    }

    var selected: ProfileRecord? {

        profiles.first {
            $0.id == selectedID
        }
    }

    func fileURL(
        for record: ProfileRecord
    ) -> URL {

        dir.appendingPathComponent(
            record.filename
        )
    }

    enum ImportError: LocalizedError {

        case unreadable
        case notAProfile
        case copyFailed

        var errorDescription: String? {

            switch self {

            case .unreadable:
                return "The file could not be read."

            case .notAProfile:
                return "Not a valid .mobileprovision file."

            case .copyFailed:
                return "The profile could not be saved."
            }
        }
    }

    // MARK: - Manual Import

    @discardableResult
    func importProfile(
        from source: URL
    ) -> Result<ProfileRecord, ImportError> {

        let scoped =
            source.startAccessingSecurityScopedResource()

        defer {

            if scoped {
                source.stopAccessingSecurityScopedResource()
            }
        }

        guard
            let data =
                try? Data(contentsOf: source)
        else {
            return .failure(.unreadable)
        }

        return importProfileData(
            data: data,
            filename: source.lastPathComponent
        )
    }

    // MARK: - Remote Import

    @discardableResult
    func importRemoteProfile(
        data: Data,
        filename: String
    ) -> Result<ProfileRecord, ImportError> {

        importProfileData(
            data: data,
            filename: filename
        )
    }

    private func importProfileData(
        data: Data,
        filename originalFilename: String
    ) -> Result<ProfileRecord, ImportError> {

        guard !data.isEmpty else {
            return .failure(.unreadable)
        }

        guard
            let info =
                ProvisioningProfileInspector.inspect(
                    data: data
                )
        else {
            return .failure(.notAProfile)
        }

        let safeFilename =
            originalFilename.isEmpty
                ? "profile.mobileprovision"
                : originalFilename

        // منع التكرار
        if let existing =
            profiles.first(
                where: {
                    $0.filename == safeFilename
                }
            ) {

            try? FileManager.default.removeItem(
                at: fileURL(for: existing)
            )

            profiles.removeAll {
                $0.id == existing.id
            }
        }

        let destination =
            dir.appendingPathComponent(
                safeFilename
            )

        do {

            try data.write(
                to: destination,
                options: .completeFileProtection
            )

        } catch {

            return .failure(.copyFailed)
        }

        let record =
            ProfileRecord(
                id: UUID(),
                filename: safeFilename,
                name: info.name,
                teamID: info.teamID,
                applicationIdentifier:
                    info.applicationIdentifier,
                notAfter:
                    info.expirationDate,
                provisionedDeviceCount:
                    info.provisionedDeviceCount,
                provisionsAllDevices:
                    info.provisionsAllDevices,
                getTaskAllow:
                    info.getTaskAllow,
                addedAt: .now
            )

        profiles.append(record)

        selectedID =
            record.id

        save()

        return .success(record)
    }

    // MARK: - Delete

    func delete(
        _ record: ProfileRecord
    ) {

        try? FileManager.default.removeItem(
            at: fileURL(for: record)
        )

        profiles.removeAll {
            $0.id == record.id
        }

        if selectedID == record.id {
            selectedID =
                profiles.first?.id
        }

        save()
    }

    // MARK: - Load

    private func load() {

        guard
            let data =
                try? Data(contentsOf: indexURL),

            let index =
                try? JSONDecoder().decode(
                    Index.self,
                    from: data
                )
        else {
            return
        }

        profiles =
            index.profiles.filter {

                FileManager.default.fileExists(
                    atPath:
                        fileURL(for: $0).path
                )
            }

        selectedID =
            index.selectedID

        if selectedID == nil {
            selectedID =
                profiles.first?.id
        }
    }

    // MARK: - Save

    private func save() {

        let index =
            Index(
                profiles: profiles,
                selectedID: selectedID
            )

        guard
            let data =
                try? JSONEncoder().encode(index)
        else {
            return
        }

        try? data.write(
            to: indexURL,
            options: .completeFileProtection
        )
    }
}

// MARK: - Provisioning Profile Inspector

enum ProvisioningProfileInspector {

    static func inspect(
        data: Data
    ) -> (
        name: String,
        teamID: String?,
        applicationIdentifier: String?,
        expirationDate: Date?,
        provisionedDeviceCount: Int?,
        provisionsAllDevices: Bool?,
        getTaskAllow: Bool?
    )? {

        for probe in probeSlices(
            in: data
        ) {

            guard
                let plist =
                    try? PropertyListSerialization.propertyList(
                        from: probe,
                        options: [],
                        format: nil
                    ),

                let dict =
                    plist as? [String: Any]
            else {
                continue
            }

            let name =
                dict["Name"] as? String
                ?? dict["ProfileName"] as? String
                ?? "Provisioning Profile"

            let entitlements =
                dict["Entitlements"]
                as? [String: Any]

            let entitlementTeamID =
                entitlements?[
                    "com.apple.developer.team-identifier"
                ] as? String

            let teamID: String?

            if let teamArray =
                dict["TeamIdentifier"] as? [String],

               let firstTeam =
                    teamArray.first {

                teamID = firstTeam

            } else {

                teamID =
                    dict["TeamIdentifier"] as? String
                    ?? entitlementTeamID
            }

            let applicationIdentifier =
                entitlements?[
                    "application-identifier"
                ] as? String

            let provisionedDeviceCount =
                (dict["ProvisionedDevices"]
                    as? [Any])?.count

            let provisionsAllDevices =
                dict["ProvisionsAllDevices"]
                    as? Bool

            let getTaskAllow =
                entitlements?[
                    "get-task-allow"
                ] as? Bool

            return (
                name,
                teamID,
                applicationIdentifier,
                dict["ExpirationDate"] as? Date,
                provisionedDeviceCount,
                provisionsAllDevices,
                getTaskAllow
            )
        }

        return nil
    }

    private static func probeSlices(
        in data: Data
    ) -> [Data] {

        var slices: [Data] = []

        let xmlMagic =
            Data("<?xml".utf8)

        let plistEnd =
            Data("</plist>".utf8)

        if let start =
            data.range(
                of: xmlMagic
            ),

           let end =
            data.range(
                of: plistEnd,
                in:
                    start.upperBound..<data.endIndex
            ) {

            slices.append(
                data.subdata(
                    in:
                        start.lowerBound..<end.upperBound
                )
            )
        }

        let binaryMagic =
            Data("bplist00".utf8)

        if let start =
            data.range(
                of: binaryMagic
            ) {

            slices.append(
                data.subdata(
                    in:
                        start.lowerBound..<data.endIndex
                )
            )
        }

        return slices
    }
}
