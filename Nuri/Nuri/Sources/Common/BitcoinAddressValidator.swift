protocol BitcoinAddressValidatorType {
    func isValid(address: String) -> Bool
}

class BitcoinAddressValidator: BitcoinAddressValidatorType {

    // Base58 characters (used in legacy and P2SH)
    private let base58Charset = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

    // Bech32 characters
    private let bech32Charset = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"

    func isValid(address: String) -> Bool {
        let length = address.count
        guard length >= 26 && length <= 42 else {
            return false
        }

        // Legacy (P2PKH): starts with 1
        if address.hasPrefix("1") {
            return isValidBase58(address)
        }

        // P2SH: starts with 3
        if address.hasPrefix("3") {
            return isValidBase58(address)
        }

        // Bech32: starts with bc1
        if address.lowercased().hasPrefix("bc1") {
            return isValidBech32(address)
        }

        return false
    }

    private func isValidBase58(_ address: String) -> Bool {
        return address.allSatisfy { base58Charset.contains($0) }
    }

    private func isValidBech32(_ address: String) -> Bool {
        let lowercaseAddress = address.lowercased()
        guard lowercaseAddress.hasPrefix("bc1") else {
            return false
        }
        let body = lowercaseAddress.dropFirst(3)
        return body.allSatisfy { bech32Charset.contains($0) }
    }
}
