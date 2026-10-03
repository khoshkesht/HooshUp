# Local save security

## Adopted design

The requested diagram contains two incompatible operations:

1. a 256-bit `DataKey` is generated in Android Keystore; and
2. `EncryptionKey = HKDF(InstallationId + DeviceSecret)` is calculated by the game.

An Android Keystore AES key is intentionally non-exportable. It can encrypt and
decrypt inside the Keystore, but GDScript cannot obtain its bytes to use as an
HKDF input or as a separate AES key. Godot 4.7's built-in `AESContext` also
supports ECB and CBC only, not AES-GCM. The GCM operation therefore has to be
performed by Android's `Cipher` API through Godot 4.7's `JavaClassWrapper` and
`AndroidRuntime` integration.

## Recommended architecture

```text
first run
  InstallationId = random UUID, stored in user://save/config.cfg
  Android Keystore = generate non-exportable AES-256/GCM key

each save
  ConfigFile -> UTF-8 bytes
  AES-256-GCM (Android Keystore key, fresh 96-bit IV,
               AAD = format + file name + InstallationId)
  -> user://save/progress.cfg or user://save/scores.cfg
```

- The binary save envelope contains a format version, key alias, IV and
  ciphertext/tag. `InstallationId` is not secret; its role is to bind a save to
  this installation through authenticated additional data (AAD).
- A modified file, copied file, or ciphertext encrypted with another key fails
  GCM authentication and is rejected.
- The key is app-scoped and non-exportable where device support permits it.
  The design does not claim to resist a rooted/instrumented device that can use
  the installed app's key while it runs, nor can it make offline score claims
  authoritative. Server-side validation is needed for competitive rewards.
- Uninstalling the app removes the Keystore key. Since the Android export
  currently disables user-data backup, that is consistent with losing local
  progress on uninstall. Do not enable backup/restore without an explicit
  recovery design.

## Migration and failure handling

1. On the first secure write, read legacy `user://progress.cfg` and
   `user://scores.cfg` once, then write their encrypted replacements.
2. Delete the plaintext source only after the encrypted write succeeds.
3. If decryption/authentication fails, preserve the unreadable file for support
   diagnostics, start with an empty store, and report a non-sensitive error.

The protected files retain their existing names, `progress.cfg` and `scores.cfg`,
even though their contents are binary AES-GCM envelopes rather than INI text.
Losing local progress after uninstall is accepted; no backup or recovery path is
implemented.

## Implementation

- `SecureSaveStore` is an autoload responsible for Android Keystore access,
  AES-GCM envelopes and migration.
- `ProgressStore` and `ScoreStore` use that autoload instead of persisting
  ConfigFiles themselves. Gameplay data stays encrypted; shipped configuration
  (`scoring_config.json`, hints) remains outside the save format.
- On non-Android platforms the store is in-memory only. This deliberately
  avoids a plaintext desktop fallback; Android device testing is required for
  persistent-save verification.
