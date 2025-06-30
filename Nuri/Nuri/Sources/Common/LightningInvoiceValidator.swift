import Foundation

protocol LightningInvoiceValidatorType {
    func isValid(invoice: String) -> Bool
}

/// A lightweight validator for Lightning Network BOLT-11 invoices.
///
/// NOTE: This does **not** fully decode / verify the Bech32 checksum or
/// signature – it only performs inexpensive heuristics that catch the vast
/// majority of invalid inputs while keeping the binary size small and the
/// implementation dependency-free.     
/// For production-critical validation you should prefer a full BOLT-11
/// implementation (e.g. via the `swift-ln` or `LibWally` packages).
final class LightningInvoiceValidator: LightningInvoiceValidatorType {

    /// Lower-cased allowed Bech32 character set minus the separator (`1`).
    private let bech32Charset = "023456789acdefghjklmnpqrstuvwxyz"

    /// Returns `true` when the supplied string looks like a Lightning invoice
    /// for mainnet (`lnbc`), testnet (`lntb`) or regtest (`lnbcrt`). The
    /// optional URI scheme prefix `lightning:` is tolerated.
    func isValid(invoice: String) -> Bool {
        // Strip leading `lightning:` URI scheme if present.
        var candidate = invoice.lowercased()
        if candidate.hasPrefix("lightning:") {
            candidate.removeFirst("lightning:".count)
        }

        // Must start with one of the BOLT-11 HRPs.
        guard candidate.hasPrefix("lnbc") || candidate.hasPrefix("lntb") || candidate.hasPrefix("lnbcrt") else {
            return false
        }

        // Invoice must contain a separator character `1`.
        guard let separatorIndex = candidate.firstIndex(of: "1") else { return false }
        let hrp = candidate[..<separatorIndex]
        let dataPart = candidate[candidate.index(after: separatorIndex)...]

        // HRP length sanity check (spec allows 1..83).
        guard hrp.count >= 4 && hrp.count <= 83 else { return false }

        // Data part must be at least 6 chars (timestamp + sig) and only use
        // Bech32 charset.
        guard dataPart.count >= 6 && dataPart.allSatisfy({ bech32Charset.contains($0) }) else {
            return false
        }

        return true
    }
} 