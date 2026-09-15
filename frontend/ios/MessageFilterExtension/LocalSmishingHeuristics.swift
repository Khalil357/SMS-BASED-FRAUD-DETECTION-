import Foundation

/// Lightweight, deterministic local checks used before deferring to Argus.
/// These intentionally do **not** reproduce the BERT model.
enum LocalSmishingHeuristics {
    struct Result {
        let isClearlyMalicious: Bool
        let reasons: [String]
    }

    static func evaluate(sender: String?, messageBody: String?) -> Result {
        let text = (messageBody ?? "").lowercased()
        let from = (sender ?? "").lowercased()
        guard !text.isEmpty else {
            return Result(isClearlyMalicious: false, reasons: ["empty_body"])
        }

        var reasons: [String] = []

        let suspiciousSenderTokens = ["alert", "verify", "secure", "bank", "support"]
        if suspiciousSenderTokens.contains(where: { from.contains($0) }) {
            reasons.append("suspicious_sender")
        }

        let hasFinancialReward =
            text.contains("win") || text.contains("won") || text.contains("prize")
            || text.contains("voucher") || text.contains("gift card")
        let hasLinkCue =
            text.contains("http://") || text.contains("https://") || text.contains("bit.ly")
            || text.contains("click") || text.contains("verify immediately")
        if hasFinancialReward && hasLinkCue {
            reasons.append("reward_plus_link")
        }

        let mobileMoney =
            text.contains("airtelmoney") || text.contains("mpesa") || text.contains("m-pesa")
            || text.contains("tigopesa") || text.contains("halopesa")
        let transferPrompt =
            text.contains("utatuma") || text.contains("tuma kwenye")
            || text.contains("hakikisha jina") || text.contains("lipia namba")
        if mobileMoney && transferPrompt {
            reasons.append("mobile_money_transfer_prompt")
        }

        let urgencyCredential =
            (text.contains("urgent") || text.contains("suspended") || text.contains("unauthorized"))
            && (text.contains("verify") || text.contains("login") || text.contains("password")
                || text.contains("account"))
            && hasLinkCue
        if urgencyCredential {
            reasons.append("urgent_credential_phish")
        }

        // Require strong combined signals before filtering offline.
        let clearlyMalicious =
            reasons.contains("reward_plus_link")
            || reasons.contains("mobile_money_transfer_prompt")
            || reasons.contains("urgent_credential_phish")

        return Result(isClearlyMalicious: clearlyMalicious, reasons: reasons)
    }
}
