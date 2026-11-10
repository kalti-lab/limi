// Makes the EdDSA (ed25519) key that signs Limi's automatic updates (Sparkle), once, without the Keychain.
//   swift scripts/make-update-key.swift [private key file] [public key file]
// The private key (base64 of the 32-byte seed, the format Sparkle's sign_update --ed-key-file reads) goes to
// ~/.kalti/signing/limi-sparkle-ed25519.key (0600), outside the repository; it is never printed. The public key
// goes to the second file (default: scripts/update-public-key.txt), and build-app.sh puts it in Info.plist
// (SUPublicEDKey). Run it only once: every copy of Limi out there trusts only this key, and losing the private key
// means those copies can no longer update themselves, so keep a backup. An existing key is never replaced.
import CryptoKit
import Foundation

let home = FileManager.default.homeDirectoryForCurrentUser.path
let args = CommandLine.arguments
let keyPath = args.count > 1 ? args[1] : home + "/.kalti/signing/limi-sparkle-ed25519.key"
let publicPath = args.count > 2 ? args[2] : "scripts/update-public-key.txt"

if FileManager.default.fileExists(atPath: keyPath) {
    FileHandle.standardError.write("\(keyPath) already exists: not replacing it (copies out there trust it).\n".data(using: .utf8)!)
    exit(1)
}
let key = Curve25519.Signing.PrivateKey()
let dir = (keyPath as NSString).deletingLastPathComponent
try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
guard FileManager.default.createFile(atPath: keyPath, contents: Data(key.rawRepresentation.base64EncodedString().utf8),
                                     attributes: [.posixPermissions: 0o600]) else {
    FileHandle.standardError.write("could not write \(keyPath)\n".data(using: .utf8)!)
    exit(1)
}
try (key.publicKey.rawRepresentation.base64EncodedString() + "\n").write(toFile: publicPath, atomically: true, encoding: .utf8)
print("private key: \(keyPath) (0600, back it up)")
print("public key:  \(publicPath)")
