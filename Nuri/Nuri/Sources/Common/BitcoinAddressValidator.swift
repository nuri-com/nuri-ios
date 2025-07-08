import Foundation
import CryptoKit

protocol BitcoinAddressValidatorType {
    /// Returns true when the supplied string is a syntactically valid on-chain
    /// Bitcoin address (Base58Check, Bech32 or Bech32m). This does **not**
    /// check whether the address belongs to a particular network (mainnet /
    /// testnet) – it only validates checksum and character constraints.
    func isValid(address: String) -> Bool
}

/// Validates on-chain Bitcoin addresses including:
///  • Legacy P2PKH & P2SH (Base58Check, version bytes 0x00 & 0x05)
///  • SegWit v0 (“bc1q…”, Bech32 checksum = 1)
///  • SegWit v1+ (“bc1p…”, Bech32m checksum = 0x2bc830a3)
///
/// The implementation is dependency-free except for CryptoKit (SHA-256).
final class BitcoinAddressValidator: BitcoinAddressValidatorType {

    // MARK: Public API
    func isValid(address: String) -> Bool {
        guard !address.isEmpty else { return false }

        // Detect address family by prefix.
        if address.first == "1" || address.first == "3" {
            return isValidBase58Check(address)
        }

        let lower = address.lowercased()
        if lower.hasPrefix("bc1") || lower.hasPrefix("tb1") || lower.hasPrefix("bcrt1") {
            return isValidBech32(address)
        }

        return false
    }

    // MARK: - Base58Check
    private let base58Alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
    private lazy var base58Map: [Character: Int] = {
        var dict: [Character: Int] = [:]
        for (i, c) in base58Alphabet.enumerated() { dict[c] = i }
        return dict
    }()

    private func isValidBase58Check(_ string: String) -> Bool {
        guard let data = base58Decode(string) else { return false }
        guard data.count >= 4 else { return false }

        let checksumIndex = data.count - 4
        let payload = data.prefix(checksumIndex)
        let checksum = data.suffix(4)

        let hash = Data(SHA256.hash(data: Data(SHA256.hash(data: payload))))
        return checksum.elementsEqual(hash.prefix(4))
    }

    /// Decodes Base58 string into raw bytes. Implementation adapted from
    /// Bitcoin Core – MIT licensed.
    private func base58Decode(_ string: String) -> Data? {
        // Reject empty string or illegal chars.
        guard !string.isEmpty, string.allSatisfy({ base58Map[$0] != nil }) else { return nil }

        // Approximate size: log(58)/log(256) ≈ 0.733.
        var bytes = Array(repeating: UInt8(0), count: Int(Double(string.count) * 0.733) + 1)

        for character in string {
            guard let cIndex = base58Map[character] else { return nil }
            var carry = cIndex
            for j in stride(from: bytes.count - 1, through: 0, by: -1) {
                carry += Int(bytes[j]) * 58
                bytes[j] = UInt8(carry & 0xff)
                carry >>= 8
            }
            // Non-zero carry at the end means overflow → invalid input.
            if carry > 0 { return nil }
        }

        // Skip leading zeroes (they correspond to '1's).
        var index = 0
        while index < bytes.count && bytes[index] == 0 { index += 1 }
        let trimmed = bytes[index...]

        // Re-add leading zeroes for each leading '1'.
        let leadingOnes = string.prefix { $0 == "1" }.count
        let result = Data(Array(repeating: 0, count: leadingOnes) + trimmed)
        return result
    }

    // MARK: - Bech32 / Bech32m
    private let bech32Charset = Array("qpzry9x8gf2tvdw0s3jn54khce6mua7l")
    private lazy var bech32Map: [Character: Int] = {
        var dict: [Character: Int] = [:]
        for (i, c) in bech32Charset.enumerated() { dict[c] = i }
        return dict
    }()

    private func isValidBech32(_ address: String) -> Bool {
        let addr = address

        // Mixed-case strings are not allowed.
        let allLower = addr == addr.lowercased()
        let allUpper = addr == addr.uppercased()
        guard allLower || allUpper else { return false }

        let address = addr.lowercased()

        guard let sepIndex = address.lastIndex(of: "1") else { return false }
        let hrp = String(address[..<sepIndex])
        let dataPart = address[address.index(after: sepIndex)...]

        guard hrp.count >= 1 && hrp.count <= 83, dataPart.count >= 6 else { return false }

        // Convert data part to values.
        var values: [Int] = []
        values.reserveCapacity(dataPart.count)
        for ch in dataPart {
            guard let idx = bech32Map[ch] else { return false }
            values.append(idx)
        }

        // Verify checksum.
        let polymod = bech32Polymod(hrpExpand(hrp) + values)

        // First data value is witness version for segwit addresses.
        let witnessVersion = values.first ?? 16
        let constant = (witnessVersion == 0) ? 1 : 0x2bc830a3 // Bech32 vs Bech32m

        return polymod == constant
    }

    /// Expands HRP per BIP-0173.
    private func hrpExpand(_ hrp: String) -> [Int] {
        var result: [Int] = []
        result.reserveCapacity(hrp.count * 2 + 1)
        for ch in hrp.utf8 { result.append(Int(ch >> 5)) }
        result.append(0)
        for ch in hrp.utf8 { result.append(Int(ch & 31)) }
        return result
    }

    /// Computes Bech32 polymod.
    private func bech32Polymod(_ values: [Int]) -> Int {
        let generator = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3]
        var chk = 1
        for v in values {
            let top = chk >> 25
            chk = (chk & 0x1ffffff) << 5 ^ v
            for i in 0..<5 {
                if ((top >> i) & 1) != 0 {
                    chk ^= generator[i]
                }
            }
        }
        return chk
    }
}
