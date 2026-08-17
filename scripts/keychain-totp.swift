#!/usr/bin/env swift
import CryptoKit
import Foundation
import Security

struct TOTPConfig: Decodable {
    let secret: String
    let algorithm: String?
    let digits: Int?
    let period: Int?
}

enum Destination {
    case clipboard
    case ios(String)
    case android(String)
}

enum HelperError: Error, CustomStringConvertible {
    case usage(String)
    case keychain(OSStatus)
    case invalidConfig(String)
    case command(String)

    var description: String {
        switch self {
        case .usage(let message), .invalidConfig(let message), .command(let message):
            return message
        case .keychain(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "unknown"
            return "Keychain lookup failed (\(status)): \(message)"
        }
    }
}

func usage() -> Never {
    fputs("""
    Usage: scripts/keychain-totp.swift --service NAME --account NAME DESTINATION

    DESTINATION (choose one):
      --clipboard          Copy the current code to the macOS clipboard
      --ios UDID           Copy the current code to an iOS Simulator clipboard
      --android SERIAL     Type the current code into the focused Android field

    The generic-password value may be a base32 seed or JSON:
      {"secret":"BASE32","algorithm":"SHA1","digits":6,"period":30}

    The seed and generated code are never printed.
    """ + "\n", stderr)
    exit(64)
}

func keychainData(service: String, account: String) throws -> Data {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: account,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    guard status == errSecSuccess, let data = result as? Data else {
        throw HelperError.keychain(status)
    }
    return data
}

func decodeBase32(_ source: String) throws -> Data {
    let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
    let lookup = Dictionary(uniqueKeysWithValues: alphabet.enumerated().map { ($1, $0) })
    let normalized = source.uppercased().filter { !$0.isWhitespace && $0 != "=" }
    guard !normalized.isEmpty else { throw HelperError.invalidConfig("The TOTP seed is empty.") }

    var buffer = 0
    var bits = 0
    var bytes: [UInt8] = []
    for character in normalized {
        guard let value = lookup[character] else {
            throw HelperError.invalidConfig("The TOTP seed is not valid base32.")
        }
        buffer = (buffer << 5) | value
        bits += 5
        if bits >= 8 {
            bits -= 8
            bytes.append(UInt8((buffer >> bits) & 0xff))
        }
    }
    return Data(bytes)
}

func code(config: TOTPConfig, now: Date = Date()) throws -> String {
    let digits = config.digits ?? 6
    let period = config.period ?? 30
    guard (6...8).contains(digits), period > 0 else {
        throw HelperError.invalidConfig("TOTP digits must be 6...8 and period must be positive.")
    }

    let key = SymmetricKey(data: try decodeBase32(config.secret))
    var counter = UInt64(now.timeIntervalSince1970) / UInt64(period)
    let message = withUnsafeBytes(of: &counter) { Data($0.reversed()) }
    let digest: [UInt8]
    switch (config.algorithm ?? "SHA1").uppercased() {
    case "SHA1":
        digest = Array(HMAC<Insecure.SHA1>.authenticationCode(for: message, using: key))
    case "SHA256":
        digest = Array(HMAC<SHA256>.authenticationCode(for: message, using: key))
    case "SHA512":
        digest = Array(HMAC<SHA512>.authenticationCode(for: message, using: key))
    default:
        throw HelperError.invalidConfig("Unsupported TOTP algorithm.")
    }

    let offset = Int(digest.last! & 0x0f)
    let value = (UInt32(digest[offset] & 0x7f) << 24)
        | (UInt32(digest[offset + 1]) << 16)
        | (UInt32(digest[offset + 2]) << 8)
        | UInt32(digest[offset + 3])
    let modulus = UInt32(pow(10.0, Double(digits)))
    return String(format: "%0*u", digits, value % modulus)
}

func run(_ executable: String, _ arguments: [String], stdin: String) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    let input = Pipe()
    process.standardInput = input
    process.standardOutput = FileHandle.nullDevice
    try process.run()
    input.fileHandleForWriting.write(Data(stdin.utf8))
    try input.fileHandleForWriting.close()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw HelperError.command("Destination command failed with status \(process.terminationStatus).")
    }
}

do {
    var service: String?
    var account: String?
    var destination: Destination?
    var index = 1
    while index < CommandLine.arguments.count {
        let argument = CommandLine.arguments[index]
        switch argument {
        case "--service", "--account", "--ios", "--android":
            guard index + 1 < CommandLine.arguments.count else { usage() }
            let value = CommandLine.arguments[index + 1]
            if argument == "--service" { service = value }
            if argument == "--account" { account = value }
            if argument == "--ios" { destination = .ios(value) }
            if argument == "--android" { destination = .android(value) }
            index += 2
        case "--clipboard":
            destination = .clipboard
            index += 1
        default:
            usage()
        }
    }

    guard let service, let account, let destination else { usage() }
    let data = try keychainData(service: service, account: account)
    let config = (try? JSONDecoder().decode(TOTPConfig.self, from: data))
        ?? TOTPConfig(secret: String(decoding: data, as: UTF8.self), algorithm: nil, digits: nil, period: nil)
    let currentCode = try code(config: config)

    switch destination {
    case .clipboard:
        try run("/usr/bin/pbcopy", [], stdin: currentCode)
    case .ios(let udid):
        try run("/usr/bin/xcrun", ["simctl", "pbcopy", udid], stdin: currentCode)
    case .android(let serial):
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["adb", "-s", serial, "shell", "input", "text", currentCode]
        process.standardOutput = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw HelperError.command("adb failed with status \(process.terminationStatus).")
        }
    }
} catch {
    fputs("keychain-totp: \(error)\n", stderr)
    exit(1)
}
