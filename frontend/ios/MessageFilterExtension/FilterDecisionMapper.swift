import Foundation
import IdentityLookup

/// Maps Argus backend / adapter JSON into an `ILMessageFilterAction`.
enum FilterDecisionMapper {
    struct ServerPayload: Decodable {
        let action: String?
        let is_scam: Bool?
        let isScam: Bool?
        let confidence: Double?
        let label: String?
    }

    static func action(from data: Data?) -> ILMessageFilterAction {
        guard let data, !data.isEmpty else {
            return .allow
        }

        guard let payload = try? JSONDecoder().decode(ServerPayload.self, from: data) else {
            return .allow
        }

        if let explicit = payload.action?.lowercased() {
            switch explicit {
            case "filter", "junk", "block":
                return .filter
            case "allow", "none":
                return .allow
            default:
                break
            }
        }

        let isScam = payload.is_scam ?? payload.isScam
            ?? (payload.label?.lowercased() == "scam" || payload.label?.lowercased() == "fraud")
        if isScam == true {
            return .filter
        }
        return .allow
    }
}
