extends Node

## Android-only secure persistence for gameplay state.
## The Keystore key never enters the Godot process; Cipher performs AES-GCM.

signal persistence_error(message: String)

const SAVE_DIRECTORY := "user://save"
const IDENTITY_PATH := SAVE_DIRECTORY + "/config.cfg"
const KEYSTORE_NAME := "AndroidKeyStore"
const KEY_ALIAS := "com.example.hooshup.save.aesgcm.v1"
const FORMAT_MAGIC := "HUP1"
const FORMAT_VERSION := 1
const GCM_TAG_BITS := 128
const GCM_TAG_BYTES := 16
const GCM_IV_BYTES := 12

var _installation_id := ""
var _android_ready := false
var _initialization_attempted := false
var _memory_documents: Dictionary = {}
var _pending_legacy_paths: Dictionary = {}

func load_config(save_name: String, legacy_path: String) -> ConfigFile:
	var config := ConfigFile.new()
	var text := load_text(save_name, legacy_path)
	if not text.is_empty() and config.parse(text) != OK:
		_report_error("Secure save data could not be parsed: %s" % save_name)
		return ConfigFile.new()
	return config

func save_config(save_name: String, config: ConfigFile) -> bool:
	return save_text(save_name, config.encode_to_text())

func load_text(save_name: String, legacy_path := "") -> String:
	if not _is_safe_save_name(save_name):
		_report_error("Invalid secure save name.")
		return ""
	if not _initialize():
		return str(_memory_documents.get(save_name, ""))
	var save_path := _get_save_path(save_name)
	if not FileAccess.file_exists(save_path):
		return _load_legacy_text(legacy_path)
	var envelope := FileAccess.get_file_as_bytes(save_path)
	var plaintext := _decrypt_envelope(save_name, envelope)
	if plaintext.is_empty() and not envelope.is_empty():
		_report_error("Secure save authentication failed: %s" % save_name)
		return ""
	return plaintext.get_string_from_utf8()

func save_text(save_name: String, text: String) -> bool:
	if not _is_safe_save_name(save_name):
		_report_error("Invalid secure save name.")
		return false
	if not _initialize():
		_memory_documents[save_name] = text
		return false
	var encrypted := _encrypt_envelope(save_name, text.to_utf8_buffer())
	if encrypted.is_empty():
		_report_error("Secure save encryption failed: %s" % save_name)
		return false
	var save_path := _get_save_path(save_name)
	var temporary_path := save_path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		_report_error("Secure save could not be written: %s" % save_name)
		return false
	file.store_buffer(encrypted)
	file.flush()
	file.close()
	if DirAccess.rename_absolute(temporary_path, save_path) != OK:
		_report_error("Secure save could not be finalized: %s" % save_name)
		return false
	_memory_documents.erase(save_name)
	_remove_migrated_legacy(save_name)
	return true

func _initialize() -> bool:
	if _initialization_attempted:
		return _android_ready
	_initialization_attempted = true
	if OS.get_name() != "Android":
		push_warning("Secure saves are in-memory outside Android; no plaintext fallback is used.")
		return false
	var android_runtime = Engine.get_singleton("AndroidRuntime")
	var java = Engine.get_singleton("JavaClassWrapper")
	if android_runtime == null or java == null:
		_report_error("Android secure-save runtime is unavailable.")
		return false
	if DirAccess.make_dir_recursive_absolute(SAVE_DIRECTORY) != OK:
		_report_error("Secure save directory could not be created.")
		return false
	_installation_id = _load_or_create_installation_id()
	if _installation_id.is_empty():
		return false
	_android_ready = _ensure_keystore_key(java)
	if not _android_ready:
		_report_error("Android Keystore key is unavailable; persistent saves are disabled.")
	return _android_ready

func _load_or_create_installation_id() -> String:
	var config := ConfigFile.new()
	if config.load(IDENTITY_PATH) == OK:
		var existing := str(config.get_value("identity", "installation_id", ""))
		if _is_uuid(existing):
			return existing
	var random_bytes := Crypto.new().generate_random_bytes(16)
	if random_bytes.size() != 16:
		_report_error("Installation ID could not be generated.")
		return ""
	# RFC 4122 version 4 / variant 1 bits.
	random_bytes[6] = (random_bytes[6] & 0x0f) | 0x40
	random_bytes[8] = (random_bytes[8] & 0x3f) | 0x80
	var hex := random_bytes.hex_encode()
	var installation_id := "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]
	config.set_value("identity", "installation_id", installation_id)
	if config.save(IDENTITY_PATH) != OK:
		_report_error("Installation ID could not be stored.")
		return ""
	return installation_id

func _ensure_keystore_key(java) -> bool:
	var KeyStore = java.wrap("java.security.KeyStore")
	var key_store = KeyStore.getInstance(KEYSTORE_NAME)
	key_store.load(null)
	if key_store.containsAlias(KEY_ALIAS):
		return true
	var KeyProperties = java.wrap("android.security.keystore.KeyProperties")
	var KeyGenParameterSpecBuilder = java.wrap("android.security.keystore.KeyGenParameterSpec$Builder")
	var KeyGenerator = java.wrap("javax.crypto.KeyGenerator")
	var purposes: int = int(KeyProperties.PURPOSE_ENCRYPT) | int(KeyProperties.PURPOSE_DECRYPT)
	var builder = KeyGenParameterSpecBuilder.Builder(KEY_ALIAS, purposes)
	builder.setKeySize(256)
	builder.setBlockModes(PackedStringArray([KeyProperties.BLOCK_MODE_GCM]))
	builder.setEncryptionPaddings(PackedStringArray([KeyProperties.ENCRYPTION_PADDING_NONE]))
	builder.setRandomizedEncryptionRequired(true)
	var generator = KeyGenerator.getInstance("AES", KEYSTORE_NAME)
	generator.init(builder.build())
	generator.generateKey()
	return true

func _encrypt_envelope(save_name: String, plaintext: PackedByteArray) -> PackedByteArray:
	var java = Engine.get_singleton("JavaClassWrapper")
	var key = _get_keystore_key(java)
	if key == null:
		return PackedByteArray()
	var Cipher = java.wrap("javax.crypto.Cipher")
	var cipher = Cipher.getInstance("AES/GCM/NoPadding")
	var CipherConstants = java.wrap("javax.crypto.Cipher")
	cipher.init(CipherConstants.ENCRYPT_MODE, key)
	var iv = cipher.getIV()
	if !(iv is PackedByteArray):
		return PackedByteArray()
	if iv.size() != GCM_IV_BYTES:
		return PackedByteArray()
	cipher.updateAAD(_aad_for(save_name))
	var ciphertext = cipher.doFinal(plaintext)
	if !(ciphertext is PackedByteArray):
		return PackedByteArray()
	if ciphertext.is_empty() and not plaintext.is_empty():
		return PackedByteArray()
	var envelope := PackedByteArray()
	envelope.append_array(FORMAT_MAGIC.to_ascii_buffer())
	envelope.append(FORMAT_VERSION)
	envelope.append(iv.size())
	envelope.append_array(iv)
	envelope.append_array(ciphertext)
	return envelope

func _decrypt_envelope(save_name: String, envelope: PackedByteArray) -> PackedByteArray:
	if envelope.size() < FORMAT_MAGIC.length() + 2 + GCM_TAG_BYTES:
		return PackedByteArray()
	if envelope.slice(0, 4).get_string_from_ascii() != FORMAT_MAGIC or envelope[4] != FORMAT_VERSION:
		return PackedByteArray()
	var iv_size := envelope[5]
	if iv_size != GCM_IV_BYTES or envelope.size() < 6 + iv_size + GCM_TAG_BYTES:
		return PackedByteArray()
	var iv := envelope.slice(6, 6 + iv_size)
	var ciphertext := envelope.slice(6 + iv_size)
	var java = Engine.get_singleton("JavaClassWrapper")
	var key = _get_keystore_key(java)
	if key == null:
		return PackedByteArray()
	var Cipher = java.wrap("javax.crypto.Cipher")
	var GCMParameterSpec = java.wrap("javax.crypto.spec.GCMParameterSpec")
	var cipher = Cipher.getInstance("AES/GCM/NoPadding")
	cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec.GCMParameterSpec(GCM_TAG_BITS, iv))
	cipher.updateAAD(_aad_for(save_name))
	var plaintext = cipher.doFinal(ciphertext)
	if !(plaintext is PackedByteArray):
		return PackedByteArray()
	return plaintext

func _get_keystore_key(java) -> Variant:
	var KeyStore = java.wrap("java.security.KeyStore")
	var key_store = KeyStore.getInstance(KEYSTORE_NAME)
	key_store.load(null)
	return key_store.getKey(KEY_ALIAS, null)

func _aad_for(save_name: String) -> PackedByteArray:
	return (FORMAT_MAGIC + ":" + str(FORMAT_VERSION) + ":" + save_name + ":" + _installation_id).to_utf8_buffer()

func _get_save_path(save_name: String) -> String:
	return SAVE_DIRECTORY + "/" + save_name

func _load_legacy_text(legacy_path: String) -> String:
	if legacy_path.is_empty() or not FileAccess.file_exists(legacy_path):
		return ""
	var legacy := ConfigFile.new()
	if legacy.load(legacy_path) != OK:
		_report_error("Legacy save could not be migrated: %s" % legacy_path)
		return ""
	_pending_legacy_paths[legacy_path.get_file()] = legacy_path
	return legacy.encode_to_text()

func _remove_migrated_legacy(save_name: String) -> void:
	if not _pending_legacy_paths.has(save_name):
		return
	var legacy_path := str(_pending_legacy_paths[save_name])
	_pending_legacy_paths.erase(save_name)
	if DirAccess.remove_absolute(legacy_path) != OK:
		_report_error("Legacy plaintext save could not be removed: %s" % legacy_path)

func _is_safe_save_name(save_name: String) -> bool:
	return not save_name.is_empty() and save_name.get_file() == save_name and not save_name.contains("..")

func _is_uuid(value: String) -> bool:
	return value.length() == 36 and value[8] == "-" and value[13] == "-" and value[18] == "-" and value[23] == "-"

func _report_error(message: String) -> void:
	push_warning(message)
	persistence_error.emit(message)
