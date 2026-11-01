# APIConfig.gd - API configuration manager
# Centrally manages all API-related configuration to avoid hardcoding and duplicated code

class_name APIConfig

# API type enum
enum APIType {
	OLLAMA,
	OPENAI,
	DEEPSEEK,
	DOUBAO,
	GEMINI,
	CLAUDE,
	SILICONFLOW,
	KIMI,
	OPENAI_COMPATIBLE  # New: OpenAI-compatible API enum value
}

# API configuration data structure
class APIProvider:
	var name: String
	var display_name: String
	var url: String
	var models: Array[String]
	var requires_api_key: bool
	var headers_template: Dictionary
	var request_format: String  # "ollama", "openai", "gemini", "claude"
	var response_parser: String  # Response parser type
	
	func _init(n: String, dn: String, u: String, m: Array[String], req_key: bool, headers: Dictionary, req_fmt: String, resp_parser: String):
		name = n
		display_name = dn
		url = u
		models = m
		requires_api_key = req_key
		headers_template = headers
		request_format = req_fmt
		response_parser = resp_parser

# Static configuration data
static var _providers: Dictionary = {}
static var _initialized: bool = false

# Initialize API provider configs
static func _initialize():
	if _initialized:
		return
	
	# Ollama config
	_providers["Ollama"] = APIProvider.new(
		"Ollama",
		"Ollama (Local)",
		"http://localhost:11434/api/generate",
		["qwen2.5:1.5b", "llama3.2:1b", "llama3.2:3b", "gemma2:2b"],
		false,
		{"Content-Type": "application/json"},
		"ollama",
		"ollama"
	)
	
	# OpenAI config
	_providers["OpenAI"] = APIProvider.new(
		"OpenAI",
		"OpenAI",
		"https://api.openai.com/v1/chat/completions",
		["gpt-4o-mini", "gpt-4o", "gpt-3.5-turbo"],
		true,
		{"Content-Type": "application/json", "Authorization": "Bearer {api_key}"},
		"openai",
		"openai"
	)
	
	# DeepSeek config
	_providers["DeepSeek"] = APIProvider.new(
		"DeepSeek",
		"DeepSeek",
		"https://api.deepseek.com/v1/chat/completions",
		["deepseek-chat"],
		true,
		{"Content-Type": "application/json", "Authorization": "Bearer {api_key}"},
		"openai",
		"openai"
	)
	
	# Doubao config
	_providers["Doubao"] = APIProvider.new(
		"Doubao",
		"Doubao (ByteDance)",
		"https://ark.cn-beijing.volces.com/api/v3/chat/completions",
		["doubao-lite-4k", "doubao-lite-32k", "doubao-lite-128k", "doubao-pro-4k", "doubao-pro-32k", "doubao-pro-128k"],
		true,
		{"Content-Type": "application/json", "Authorization": "Bearer {api_key}"},
		"openai",
		"openai"
	)
	
	# Gemini config
	_providers["Gemini"] = APIProvider.new(
		"Gemini",
		"Gemini (Google)",
		"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
		["gemini-1.5-flash", "gemini-1.5-pro", "gemini-1.0-pro"],
		true,
		{"Content-Type": "application/json", "x-goog-api-key": "{api_key}"},
		"gemini",
		"gemini"
	)
	
	# Claude config
	_providers["Claude"] = APIProvider.new(
		"Claude",
		"Claude (Anthropic)",
		"https://api.anthropic.com/v1/messages",
		["claude-opus-5-5", "claude-sonnet-5-5", "claude-haiku-5-5"],
		true,
		# The Anthropic API authenticates with x-api-key (not Authorization: Bearer)
		{"Content-Type": "application/json", "x-api-key": "{api_key}", "anthropic-version": "2026-10-21"},
		"claude",
		"claude"
	)
	
	# KIMI config
	_providers["KIMI"] = APIProvider.new(
		"KIMI",
		"KIMI (Moonshot AI)",
		"https://api.moonshot.cn/v1/chat/completions",
		["moonshot-v1-8k", "moonshot-v1-32k", "moonshot-v1-128k"],
		true,
		{"Content-Type": "application/json", "Authorization": "Bearer {api_key}"},
		"openai",
		"openai"
	)


	# SiliconFlow config
	_providers["SiliconFlow"] = APIProvider.new(
		"SiliconFlow",
		"SiliconFlow",
		"https://api.siliconflow.cn/v1/chat/completions",
		["deepseek-ai/DeepSeek-V3.1-Terminus", "inclusionAI/Ring-1T", "zai-org/GLM-4.6"],
		true,
		{"Content-Type": "application/json", "Authorization": "Bearer {api_key}"},
		"openai",
		"openai"
	)
	
# New: generic OpenAI Compatible provider
	# The URL here is a placeholder, replaced at runtime or set via a config file
	_providers["OpenAICompatible"] = APIProvider.new(
		"OpenAICompatible",
		"OpenAI Compatible (Custom)",
		"https://custom-openai-compatible.com/v1/chat/completions",  # Placeholder URL; can be extended to support dynamic configuration
		[],  # Empty model list; specified by the user or loaded dynamically
		true,
		{"Content-Type": "application/json", "Authorization": "Bearer {api_key}"},
		"openai",
		"openai"
	)
	
	_initialized = true

# Get all API provider names (automatically includes new ones)
static func get_api_types() -> Array[String]:
	_initialize()
	var result: Array[String] = []
	for key in _providers.keys():
		result.append(key)
	return result

# Get an API provider's config
static func get_provider(api_type: String) -> APIProvider:
	_initialize()
	return _providers.get(api_type, _providers["Ollama"])

# Get the model list for the given API
static func get_models_for_api(api_type: String) -> Array[String]:
	_initialize()
	var provider = get_provider(api_type)
	return provider.models

# Check whether the API requires a key
static func requires_api_key(api_type: String) -> bool:
	_initialize()
	var provider = get_provider(api_type)
	return provider.requires_api_key

# Build the request data
static func build_request_data(api_type: String, model: String, prompt: String) -> Dictionary:
	_initialize()
	var provider = get_provider(api_type)
	
	match provider.request_format:
		"ollama":
			return {
				"model": model,
				"prompt": prompt,
				"stream": false
			}
		"openai":
			return {
				"model": model,
				"messages": [{
					"role": "user",
					"content": prompt
				}]
			}
		"gemini":
			return {
				"contents": [{
					"parts": [{
						"text": prompt
					}]
				}]
			}
		"claude":
			# Current Claude models always have thinking enabled, and thinking tokens count toward max_tokens,
			# so leave headroom; use low effort for short dialog to reduce latency and cost
			return {
				"model": model,
				"max_tokens": 4096,
				"output_config": {"effort": "low"},
				"messages": [{
					"role": "user",
					"content": prompt
				}]
			}
		_:
			return {}

# Build the request headers
static func build_headers(api_type: String, api_key: String) -> Array[String]:
	_initialize()
	var provider = get_provider(api_type)
	var headers: Array[String] = []
	
	for key in provider.headers_template:
		var value = provider.headers_template[key]
		if value.find("{api_key}") != -1:
			value = value.replace("{api_key}", api_key)
		headers.append(key + ": " + value)
	
	return headers

# Get the request URL (adds handling for compatible mode; extend here if a dynamic URL is needed)
static func get_url(api_type: String, model: String = "") -> String:
	_initialize()
	var provider = get_provider(api_type)
	var url = provider.url
	
	if url.find("{model}") != -1:
		url = url.replace("{model}", model)
	
	# New: if api_type is OpenAICompatible, custom logic can be added here (e.g. read the URL from a global config)
	# if api_type == "OpenAICompatible":
	#     url = GlobalConfig.custom_openai_url  # Example extension, requires project support
	 
	return url

# Parse the API response
static func parse_response(api_type: String, response: Dictionary, character_name: String = "") -> String:
	_initialize()
	var provider = get_provider(api_type)
	
	match provider.response_parser:
		"ollama":
			if not "response" in response:
				print("[APIConfig] Ollama API response for %s is malformed: missing response field" % character_name)
				return ""
			return response.response
		
		"openai":
			if not "choices" in response or not response.has("choices") or response.choices.size() == 0:
				print("[APIConfig] OpenAI-format API response for %s is malformed: choices field missing or empty" % character_name)
				return ""
			if not response.choices[0].has("message") or not response.choices[0].message.has("content"):
				print("[APIConfig] OpenAI-format API response for %s is malformed: missing message or content field" % character_name)
				return ""
			return response.choices[0].message.content
		
		"gemini":
			if not "candidates" in response or response.candidates.size() == 0:
				print("[APIConfig] Gemini API response for %s is malformed: candidates field missing or empty" % character_name)
				return ""
			if not response.candidates[0].has("content") or not response.candidates[0].content.has("parts") or response.candidates[0].content.parts.size() == 0:
				print("[APIConfig] Gemini API response for %s is malformed: missing content or parts field" % character_name)
				return ""
			return response.candidates[0].content.parts[0].text
		
		"claude":
			if response.get("stop_reason", "") == "refusal":
				print("[APIConfig] Claude request for %s was refused (refusal)" % character_name)
				return ""
			if not "content" in response or not response.content is Array or response.content.size() == 0:
				print("[APIConfig] Claude API response for %s is malformed: content field missing or empty" % character_name)
				return ""
			# content may start with thinking blocks; only concatenate blocks whose type is text
			var text := ""
			for block in response.content:
				if block is Dictionary and block.get("type", "") == "text":
					text += str(block.get("text", ""))
			if text == "":
				print("[APIConfig] Claude API response for %s is malformed: no text content blocks" % character_name)
			return text
		
		_:
			print("[APIConfig] Unknown API type for %s, using default handling" % character_name)
			return ""
