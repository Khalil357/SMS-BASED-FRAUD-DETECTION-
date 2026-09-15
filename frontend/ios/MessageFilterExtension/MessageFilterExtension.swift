import IdentityLookup

/// Native Message Filter Extension for Argus.
/// Receives eligible unknown-sender SMS/MMS from iOS, applies cheap local heuristics,
/// and defers authoritative classification to the Argus backend via Apple's
/// system-mediated `deferQueryRequestToNetwork` path (no direct URLSession).
final class MessageFilterExtension: ILMessageFilterExtension {}

extension MessageFilterExtension: ILMessageFilterQueryHandling {
    func handle(
        _ queryRequest: ILMessageFilterQueryRequest,
        context: ILMessageFilterExtensionContext,
        completion: @escaping (ILMessageFilterQueryResponse) -> Void
    ) {
        let response = ILMessageFilterQueryResponse()
        let sender = queryRequest.sender
        let body = queryRequest.messageBody

        // Offline first-pass (local-first philosophy). Strong signals only.
        let local = LocalSmishingHeuristics.evaluate(sender: sender, messageBody: body)
        if local.isClearlyMalicious {
            response.action = FilterDecisionMapper.action(from: Self.filterJson)
            completion(response)
            return
        }

        // Authoritative path: Apple OS posts to ILMessageFilterExtensionNetworkURL.
        context.deferQueryRequestToNetwork { networkResponse, error in
            if error != nil || networkResponse == nil {
                // Fail open: do not filter when the backend/network is unavailable.
                response.action = .allow
                completion(response)
                return
            }

            response.action = FilterDecisionMapper.action(from: networkResponse?.data)
            completion(response)
        }
    }

    private static var filterJson: Data {
        Data(#"{"action":"filter","is_scam":true,"label":"scam"}"#.utf8)
    }
}
