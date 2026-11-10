## programs\.open-code-review\.enable

Whether to enable Open Code Review, the ` ocr ` code-review CLI\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/open-code-review>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/open-code-review)



## programs\.open-code-review\.package



The open-code-review package\. Comes from numtide/llm-agents\.nix: apply its
` overlays.shared-nixpkgs ` or set this option\.



*Type:*
null or package



*Default:*

```nix
pkgs.llm-agents.open-code-review
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/open-code-review>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/open-code-review)



## programs\.open-code-review\.installWrapper



Whether to install the ` ocr ` wrapper in the Home Manager profile\. Turn it off
when the wrapper comes from another profile; build it there with
` lib.openCodeReview.mkWrapper `\. The settings merge and the viewer unit stay\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/open-code-review>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/open-code-review)



## programs\.open-code-review\.settings



Keys merged into ` ~/.opencodereview/config.json ` on activation
(see the upstream configuration docs)\. Literal API keys land in the
Nix store; use ` api_key_cmd ` for real secrets\.



*Type:*
JSON value



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  provider = "local";
  model = "qwen3-coder";
  custom_providers.local = {
    url = "http://127.0.0.1:8080/v1";
    protocol = "openai";
    api_key = "local";
  };
}

```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/open-code-review>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/open-code-review)



## programs\.open-code-review\.telemetry\.enable



Whether to enable OTLP/HTTP trace and metric export\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/open-code-review>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/open-code-review)



## programs\.open-code-review\.telemetry\.endpoint



OTLP/HTTP base URL; ` /v1/traces ` and ` /v1/metrics ` are appended\.



*Type:*
string



*Example:*

```nix
"http://127.0.0.1:6006"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/open-code-review>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/open-code-review)



## programs\.open-code-review\.telemetry\.headersFile



JSON object of HTTP headers for the exporter, read at every run,
for example a file holding an API key header\.



*Type:*
string

*Declared by:*
 - [\<nixpkgs-extra/modules/home/open-code-review>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/open-code-review)



## programs\.open-code-review\.telemetry\.metrics\.enable



Whether to export metrics\. Turn it off for backends that only ingest
traces; it sets ` OTEL_METRICS_EXPORTER=none `\. The package must honor
that variable (stock OCR 1\.13\.3 does not)\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/open-code-review>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/open-code-review)



## programs\.open-code-review\.telemetry\.resourceAttributes



OpenTelemetry resource attributes (` OTEL_RESOURCE_ATTRIBUTES `); Some backends
take the project from ` openinference.project.name `\.



*Type:*
attribute set of string



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  "openinference.project.name" = "open-code-review";
}
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/open-code-review>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/open-code-review)



## programs\.open-code-review\.telemetry\.serviceName



OpenTelemetry ` service.name `\.



*Type:*
string



*Default:*

```nix
"open-code-review"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/open-code-review>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/open-code-review)



## programs\.open-code-review\.viewer\.enable



Whether to enable the session viewer (` ocr viewer `) as a user service\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/open-code-review>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/open-code-review)



## programs\.open-code-review\.viewer\.allowedHosts



Extra Host headers the viewer accepts besides loopback
(` OCR_VIEWER_ALLOWED_HOSTS `), for a reverse proxy in front of it\.



*Type:*
list of string



*Default:*

```nix
[ ]
```



*Example:*

```nix
[
  "ocr.localhost"
]
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/open-code-review>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/open-code-review)



## programs\.open-code-review\.viewer\.port



Loopback port of the viewer\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
5483
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/open-code-review>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/open-code-review)



## programs\.openviking-server\.enable



Whether to enable the per-user OpenViking context-filesystem server\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.package



The openviking-server package to run\.



*Type:*
package



*Default:*

```nix
pkgs.openviking-server
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.afterUnits



User units to order the server after (and want), for example one that
materialises ` apiKeyFile ` before the runner reads it\.



*Type:*
list of string



*Default:*

```nix
[ ]
```



*Example:*

```nix
[
  "secrets-provisioner.service"
]
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.apiKeyFile



File holding the provider API key, read at service start and injected
into both the embedding and VLM blocks of the rendered ov\.conf\. Keeps
the key out of the Nix store\. Ignored when ` configFile ` is set\.



*Type:*
null or absolute path



*Default:*

```nix
null
```



*Example:*

```nix
"/run/user/1000/openrouter-key"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.botAgentModel



Model id for the vikingbot gateway agent (ov\.conf ` bot.agents.model `)\.
Null leaves the section unset so the bot inherits the root ` vlm `\.
When set, the bot’s provider chain becomes explicit: the runner
injects the apiKeyFile key into bot\.agents\.api_key, and provider /
api_base fall back to the vlm option’s values\.



*Type:*
null or string



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.configFile



Path to an OpenViking ` ov.conf ` (JSON) describing storage, logging,
embedding and VLM providers\. Passed as ` --config `\. When set it takes
precedence over any structured config the module would build\.



*Type:*
null or absolute path



*Default:*

```nix
null
```



*Example:*

```nix
"/run/secrets/ov.conf"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.embedding



Embedding provider configuration (defaults to OpenRouter’s OpenAI-compatible endpoint)\.



*Type:*
submodule



*Default:*

```nix
{ }
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.embedding\.allowMetadataOverride



ov\.conf ` embedding.allow_metadata_override `: adopt an existing
vector collection whose provider/model metadata differs from the
current config, as long as the dimension is unchanged\. The server
rewrites the collection metadata and keeps the vectors\. Use when
the same model moved to a new endpoint id; never across genuinely
different models (vector semantics must match)\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.embedding\.apiBase



Base URL of the OpenAI-compatible endpoint\.



*Type:*
string



*Default:*

```nix
"https://openrouter.ai/api/v1"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.embedding\.apiKey



Literal API key\. Insecure: it lands in the Nix store\. Prefer
leaving this null and setting ` apiKeyFile `, which the runner injects
at start\.



*Type:*
null or string



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.embedding\.dimension



Embedding output dimension (text-embedding-3-small is 1536)\.



*Type:*
null or (positive integer, meaning >0)



*Default:*

```nix
1536
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.embedding\.fallback



Failover endpoint tried when the primary fails\. Null renders no
` credentials ` list, so the server uses the primary alone\. Only
` embedding ` and ` vlm ` render it; ` queryPlanner ` ignores it\.



*Type:*
null or (submodule)



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.embedding\.fallback\.apiBase



Base URL of the fallback OpenAI-compatible endpoint\.



*Type:*
string



*Default:*

```nix
"https://openrouter.ai/api/v1"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.embedding\.fallback\.apiKey



Literal API key\. Insecure: prefer fallbackApiKeyFile\.



*Type:*
null or string



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.embedding\.fallback\.model



Model id at the fallback endpoint\.



*Type:*
string

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.embedding\.fallback\.provider



Provider client for the fallback endpoint\.



*Type:*
string



*Default:*

```nix
"openai"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.embedding\.maxConcurrent



Maximum concurrent requests to the provider\.



*Type:*
positive integer, meaning >0



*Default:*

```nix
4
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.embedding\.maxInputTokens



Estimated-token cap per embedding input (` embedding.max_input_tokens `)\.
The server truncates longer text and estimates 4 characters per
token, which undercounts code\. Null sends every input whole\.



*Type:*
null or (positive integer, meaning >0)



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.embedding\.model



Embedding model id\.



*Type:*
string



*Default:*

```nix
"openai/text-embedding-3-small"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.embedding\.provider



Provider client OpenViking uses (` openai ` selects the OpenAI-compatible HTTP client)\.



*Type:*
string



*Default:*

```nix
"openai"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.environment



Extra environment variables for the server unit\.



*Type:*
attribute set of string



*Default:*

```nix
{ }
```



*Example:*

```nix
{ OPENVIKING_PUBLIC_BASE_URL = "https://ov.example.org"; }
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.environmentFiles



EnvironmentFiles for the unit (e\.g\. a secret-manager-rendered file),
read at start without entering the store\.



*Type:*
list of absolute path



*Default:*

```nix
[ ]
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.fallbackApiKeyFile



File holding the key for ` embedding.fallback ` / ` vlm.fallback `, read
at service start and injected into those credentials only\. Ignored
when ` configFile ` is set\.



*Type:*
null or absolute path



*Default:*

```nix
null
```



*Example:*

```nix
"/run/user/1000/openrouter-key"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.host



Address the server binds to (passed as ` --host `)\. Defaults to
loopback\.



*Type:*
string



*Default:*

```nix
"127.0.0.1"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.logLevel



Log level written to the ov\.conf ` log.level `\.



*Type:*
string



*Default:*

```nix
"INFO"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.port



TCP port the server binds to (passed as ` --port `)\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
1933
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.queryPlanner



Retrieval intent / query-planner model (ov\.conf ` query_planner `)\.
Null leaves the section unset so the server falls back to ` vlm `\.



*Type:*
null or (submodule)



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.queryPlanner\.apiBase



Base URL of the OpenAI-compatible endpoint\.



*Type:*
string



*Default:*

```nix
"https://openrouter.ai/api/v1"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.queryPlanner\.apiKey



Literal API key\. Insecure: it lands in the Nix store\. Prefer
leaving this null and setting ` apiKeyFile `, which the runner injects
at start\.



*Type:*
null or string



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.queryPlanner\.fallback



Failover endpoint tried when the primary fails\. Null renders no
` credentials ` list, so the server uses the primary alone\. Only
` embedding ` and ` vlm ` render it; ` queryPlanner ` ignores it\.



*Type:*
null or (submodule)



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.queryPlanner\.fallback\.apiBase



Base URL of the fallback OpenAI-compatible endpoint\.



*Type:*
string



*Default:*

```nix
"https://openrouter.ai/api/v1"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.queryPlanner\.fallback\.apiKey



Literal API key\. Insecure: prefer fallbackApiKeyFile\.



*Type:*
null or string



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.queryPlanner\.fallback\.extraRequestBody



Extra JSON merged into each request body (` extra_request_body `)\.



*Type:*
attribute set



*Default:*

```nix
{ }
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.queryPlanner\.fallback\.model



Model id at the fallback endpoint\.



*Type:*
string

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.queryPlanner\.fallback\.provider



Provider client for the fallback endpoint\.



*Type:*
string



*Default:*

```nix
"openai"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.queryPlanner\.maxConcurrent



Maximum concurrent requests to the provider\.



*Type:*
positive integer, meaning >0



*Default:*

```nix
4
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.queryPlanner\.model



Vision/LLM model id\.



*Type:*
string



*Default:*

```nix
"openai/gpt-4o-mini"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.queryPlanner\.provider



Provider client OpenViking uses (` openai ` selects the OpenAI-compatible HTTP client)\.



*Type:*
string



*Default:*

```nix
"openai"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.queryPlanner\.timeout



Per-request HTTP timeout in seconds (ov\.conf ` vlm.timeout `)\. Null
keeps the server default (600)\.



*Type:*
null or (positive integer, meaning >0)



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.rerank



Rerank provider (ov\.conf ` rerank `)\. Null leaves the section unset
(rerank off)\. Unlike embedding/vlm, apiBase must be the full
rerank endpoint URL: the server’s OpenAI-compatible rerank
client POSTs to it verbatim\.



*Type:*
null or (submodule)



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.rerank\.apiBase



Full rerank endpoint URL (the client POSTs to this exact URL)\.



*Type:*
string

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.rerank\.apiKey



Literal API key\. Insecure: prefer apiKeyFile injection\.



*Type:*
null or string



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.rerank\.maxInputTokens



Estimated-token cap per query+document pair (` max_input_tokens `)\.
Null keeps the server default (0, unlimited)\.



*Type:*
null or (unsigned integer, meaning >=0)



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.rerank\.model



Rerank model id\.



*Type:*
string

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.rerank\.provider



Rerank provider (` openai ` selects the OpenAI-compatible flat-protocol client)\.



*Type:*
string



*Default:*

```nix
"openai"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.settingsExtra



Extra attributes merged into the generated ov\.conf\.



*Type:*
attribute set



*Default:*

```nix
{ }
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.vlm



Vision/LLM provider configuration (defaults to OpenRouter’s OpenAI-compatible endpoint)\.



*Type:*
submodule



*Default:*

```nix
{ }
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.vlm\.apiBase



Base URL of the OpenAI-compatible endpoint\.



*Type:*
string



*Default:*

```nix
"https://openrouter.ai/api/v1"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.vlm\.apiKey



Literal API key\. Insecure: it lands in the Nix store\. Prefer
leaving this null and setting ` apiKeyFile `, which the runner injects
at start\.



*Type:*
null or string



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.vlm\.fallback



Failover endpoint tried when the primary fails\. Null renders no
` credentials ` list, so the server uses the primary alone\. Only
` embedding ` and ` vlm ` render it; ` queryPlanner ` ignores it\.



*Type:*
null or (submodule)



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.vlm\.fallback\.apiBase



Base URL of the fallback OpenAI-compatible endpoint\.



*Type:*
string



*Default:*

```nix
"https://openrouter.ai/api/v1"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.vlm\.fallback\.apiKey



Literal API key\. Insecure: prefer fallbackApiKeyFile\.



*Type:*
null or string



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.vlm\.fallback\.extraRequestBody



Extra JSON merged into each request body (` extra_request_body `)\.



*Type:*
attribute set



*Default:*

```nix
{ }
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.vlm\.fallback\.model



Model id at the fallback endpoint\.



*Type:*
string

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.vlm\.fallback\.provider



Provider client for the fallback endpoint\.



*Type:*
string



*Default:*

```nix
"openai"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.vlm\.maxConcurrent



Maximum concurrent requests to the provider\.



*Type:*
positive integer, meaning >0



*Default:*

```nix
4
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.vlm\.model



Vision/LLM model id\.



*Type:*
string



*Default:*

```nix
"openai/gpt-4o-mini"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.vlm\.provider



Provider client OpenViking uses (` openai ` selects the OpenAI-compatible HTTP client)\.



*Type:*
string



*Default:*

```nix
"openai"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.vlm\.timeout



Per-request HTTP timeout in seconds (ov\.conf ` vlm.timeout `)\. Null
keeps the server default (600)\.



*Type:*
null or (positive integer, meaning >0)



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.openviking-server\.workspace



Per-user state directory\. The server’s workspace is created at
` <workspace>/.openviking ` by the runner at start\.



*Type:*
string



*Default:*

```nix
"${config.xdg.dataHome}/openviking"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/openviking-server)



## programs\.phoenix\.enable



Whether to enable Phoenix tracing of every enabled AI process\. Sends prompts, model
output and tool input/output to ` programs.phoenix.endpoint `\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/phoenix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/phoenix)



## programs\.phoenix\.apiKeyFile



File holding the Phoenix system API key, read at run time\.



*Type:*
string



*Example:*

```nix
"/run/secrets/phoenix-api-key"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/phoenix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/phoenix)



## programs\.phoenix\.claudePluginPackage



The Claude Code tracing plugin (Arize coding-harness-tracing); it
also provides the Codex notify command through
` passthru.codexNotify `\. Not shipped by this repository: without it
Claude Code is only wrapped with the Phoenix environment, loads no
plugin, and ` programs.phoenix.codexNotify ` is unavailable\.



*Type:*
null or package



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/phoenix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/phoenix)



## programs\.phoenix\.codexNotify



Codex ` notify ` command that sends a turn to Phoenix; null while no
` programs.phoenix.claudePluginPackage ` is set\.



*Type:*
null or string *(read only)*



*Default:*

```nix
config.programs.phoenix.claudePluginPackage.passthru.codexNotify
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/phoenix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/phoenix)



## programs\.phoenix\.endpoint



Phoenix base URL (the hooks append ` /v1/traces `)\.



*Type:*
string



*Default:*

```nix
"http://127.0.0.1:6006"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/phoenix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/phoenix)



## programs\.phoenix\.extraEnv



Extra non-secret variables for the wrapped harnesses\.



*Type:*
attribute set of string



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  ARIZE_LOG_TOOL_CONTENT = "false";
}
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/phoenix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/phoenix)



## programs\.phoenix\.mcpCommand



Stdio launcher of the Phoenix MCP server for harness MCP configs\.



*Type:*
string *(read only)*



*Default:*
a launcher script that exports the API key and endpoint, then runs ` programs.phoenix.mcpPackage `

*Declared by:*
 - [\<nixpkgs-extra/modules/home/phoenix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/phoenix)



## programs\.phoenix\.mcpPackage



The Phoenix MCP server\.



*Type:*
package



*Default:*

```nix
pkgs.phoenix-mcp
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/phoenix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/phoenix)



## programs\.phoenix\.project



Phoenix project that receives the traces (PHOENIX_PROJECT)\.



*Type:*
string



*Default:*

```nix
"agents"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/phoenix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/phoenix)



## programs\.phoenix\.userId



User id attached to every trace (ARIZE_USER_ID); null to omit\.



*Type:*
null or string



*Default:*

```nix
config.home.username
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/phoenix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/phoenix)



## services\.agentsview\.enable



Whether to enable the agentsview session browser as a user service\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/agentsview>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/agentsview)



## services\.agentsview\.package



The agentsview package\. Comes from numtide/llm-agents\.nix: apply its
` overlays.shared-nixpkgs ` or set this option\.



*Type:*
null or package



*Default:*

```nix
pkgs.llm-agents.agentsview
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/agentsview>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/agentsview)



## services\.agentsview\.dataDir



Directory of the SQLite index and config\.toml; agentsview creates it\.



*Type:*
string



*Default:*

```nix
"${config.home.homeDirectory}/.agentsview"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/agentsview>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/agentsview)



## services\.agentsview\.environment



Extra environment of the service and the maintenance units\. A dead
proxy here keeps agentsview offline if a firewall rule fails (Go
never proxies loopback, so the UI and the gateway still work)\.



*Type:*
attribute set of string



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  HTTP_PROXY = "http://127.0.0.1:9";
}
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/agentsview>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/agentsview)



## services\.agentsview\.llama\.enable



Whether to enable semantic search and Recall extraction through the model gateway of ` services.llamaServers `\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/agentsview>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/agentsview)



## services\.agentsview\.llama\.apiKeyFile



File holding the gateway bearer key, passed to the unit as a credential\.



*Type:*
null or absolute path



*Default:*

```nix
config.services.llamaServers.masterKeyFile
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/agentsview>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/agentsview)



## services\.agentsview\.llama\.dimension



Vector dimension of the embedding model\.



*Type:*
positive integer, meaning >0



*Example:*

```nix
4096
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/agentsview>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/agentsview)



## services\.agentsview\.llama\.embeddingModel



Gateway model name used for embeddings (a key of ` services.llamaServers.models `)\.



*Type:*
string



*Example:*

```nix
"qwen3-emb-8b"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/agentsview>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/agentsview)



## services\.agentsview\.llama\.endpoint



OpenAI-compatible base URL of the gateway\.



*Type:*
string



*Default:*

```nix
config.services.llamaServers.gatewayURL
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/agentsview>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/agentsview)



## services\.agentsview\.llama\.extractModel



Gateway model name used for Recall extraction: a key of
` services.llamaServers.models ` or ` anthropicModels `\. A large local
model on the CPU can hold many GB for days of backlog, so a cloud
model is often the better choice\.



*Type:*
string



*Example:*

```nix
"claude-haiku"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/agentsview>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/agentsview)



## services\.agentsview\.llama\.queryPrefix



Prefix agentsview puts before search queries, for instruction-tuned
embedding models\. Null sends the query as is\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
''
  Instruct: Given a search query, retrieve relevant passages from coding agent session transcripts
  Query:''
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/agentsview>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/agentsview)



## services\.agentsview\.lowPriority



Run the units at Nice 10, idle I/O class and CPUWeight 20: indexing must not compete with the desktop\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/agentsview>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/agentsview)



## services\.agentsview\.maintenance\.enable



Run the periodic secrets scan and database compaction\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/agentsview>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/agentsview)



## services\.agentsview\.maintenance\.compact\.onCalendar



Schedule of ` agentsview db compact --yes `\.



*Type:*
string



*Default:*

```nix
"weekly"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/agentsview>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/agentsview)



## services\.agentsview\.maintenance\.secretsScan\.onCalendar



Schedule of ` agentsview secrets scan --backfill `\. Recall extraction
only takes sessions with a full secret scan\.



*Type:*
string



*Default:*

```nix
"daily"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/agentsview>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/agentsview)



## services\.agentsview\.memoryHigh



MemoryHigh of the service (throttling starts here)\.



*Type:*
string



*Default:*

```nix
"2G"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/agentsview>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/agentsview)



## services\.agentsview\.memoryMax



MemoryMax of the service (the OOM limit)\.



*Type:*
string



*Default:*

```nix
"4G"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/agentsview>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/agentsview)



## services\.agentsview\.port



Loopback port of the web UI\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
8086
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/agentsview>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/agentsview)



## services\.agentsview\.publicOrigins



Extra origins that pass the Host and Origin checks (` --public-origin `),
for a reverse proxy in front of the UI\.



*Type:*
list of string



*Default:*

```nix
[ ]
```



*Example:*

```nix
[
  "http://agentsview.localhost"
]
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/agentsview>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/agentsview)



## services\.agentsview\.readOnlyPaths



Session roots the unit sees read-only\. With ` sandbox.enable ` the whole
home is read-only already; list roots outside the home here\.



*Type:*
list of string



*Default:*

```nix
map (p: "${config.home.homeDirectory}/" + p) [
  ".claude"
  ".codex"
  ".local/share/opencode"
  ".hermes"
]

```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/agentsview>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/agentsview)



## services\.agentsview\.sandbox\.enable



Mount the home read-only and the system strict, with dataDir the only
writable path, and set the other systemd sandbox options\. Turn it off
if a session root needs write access or the sandbox does not start
in your setup\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/agentsview>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/agentsview)



## services\.agentsview\.settings



Top-level tables Nix owns in config\.toml\. Each listed table is
replaced wholesale at activation; everything else (auth_token,
cursor_secret) stays agentsview’s\. The daemon reads the file only at
start, so a change restarts the service\. ` vector ` and ` recall ` are
always owned: ` llama.enable ` fills them, and without it they are
written disabled\.



*Type:*
TOML value



*Default:*

```nix
{ }
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/agentsview>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/agentsview)



## services\.grafanaCloud\.enable



Whether to enable shipping telemetry to Grafana Cloud via Grafana Alloy\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.package



Grafana Alloy package to run\.



*Type:*
package



*Default:*

```nix
pkgs.grafana-alloy
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.environment



Value for an ` env ` external label\. No label is added when null\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"prod"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.environmentFile



Path to a systemd EnvironmentFile that defines ` GC_TOKEN `, a
Grafana Cloud Access Policy token valid for every enabled signal\.
Required when the module is enabled\. The file is read at run time
and never copied to the Nix store\.



*Type:*
null or absolute path



*Default:*

```nix
null
```



*Example:*

```nix
"/run/secrets/grafana-cloud.env"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.externalLabels



Extra external labels attached to every signal\.



*Type:*
attribute set of string



*Default:*

```nix
{ }
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.extraConfig



Extra Alloy (River) configuration appended verbatim\.



*Type:*
strings concatenated with “\\n”



*Default:*

```nix
""
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.logs\.enable



Send logs to Grafana Cloud Loki\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.logs\.endpoint



Loki push endpoint URL of the Grafana Cloud stack\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"https://logs-prod-012.grafana.net/loki/api/v1/push"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.logs\.files



Log files to tail\.



*Type:*
list of (submodule)



*Default:*

```nix
[ ]
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.logs\.files\.\*\.labels



Additional labels\.



*Type:*
attribute set of string



*Default:*

```nix
{ }
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.logs\.files\.\*\.path



Glob path to tail\.



*Type:*
string



*Example:*

```nix
"/var/log/*.log"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.logs\.journal



Forward systemd journal entries\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.logs\.user



Basic-auth username (the instance ID of this signal in the stack)\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"1234567"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.metrics\.enable



Send metrics to Grafana Cloud Prometheus\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.metrics\.endpoint



Prometheus remote_write endpoint URL of the Grafana Cloud stack\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"https://prometheus-prod-01-eu-west-0.grafana.net/api/prom/push"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.metrics\.extraScrapeTargets



Additional static scrape targets\.



*Type:*
list of (submodule)



*Default:*

```nix
[ ]
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.metrics\.extraScrapeTargets\.\*\.address



host:port of the scrape target\.



*Type:*
string



*Example:*

```nix
"127.0.0.1:9100"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.metrics\.extraScrapeTargets\.\*\.job



Prometheus ` job ` label\.



*Type:*
string

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.metrics\.extraScrapeTargets\.\*\.labels



Additional labels\.



*Type:*
attribute set of string



*Default:*

```nix
{ }
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.metrics\.nodeExporter



Enable the built-in ` prometheus.exporter.unix ` (node exporter)\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.metrics\.nodeExporterCollectors



Collectors enabled on ` prometheus.exporter.unix `\.



*Type:*
list of string



*Default:*

```nix
[
  "cpu"
  "diskstats"
  "filesystem"
  "loadavg"
  "meminfo"
  "netdev"
  "netstat"
  "stat"
  "time"
  "uname"
  "vmstat"
]
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.metrics\.scrapeInterval



Scrape interval for the built-in scrape jobs\.



*Type:*
string



*Default:*

```nix
"60s"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.metrics\.smartctl\.enable



Run the smartctl exporter and scrape it for SMART attributes\.
Honoured by the NixOS module only\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.metrics\.smartctl\.devices



Devices to monitor\. Empty means autodiscover\.



*Type:*
list of string



*Default:*

```nix
[ ]
```



*Example:*

```nix
[
  "/dev/sda"
  "/dev/nvme0n1"
]
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.metrics\.smartctl\.listenAddress



Listen address of the smartctl exporter\.



*Type:*
string



*Default:*

```nix
"127.0.0.1"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.metrics\.smartctl\.maxInterval



Minimum interval between SMART queries per disk\.



*Type:*
string



*Default:*

```nix
"60s"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.metrics\.smartctl\.port



TCP port of the smartctl exporter\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
9633
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.metrics\.user



Basic-auth username (the instance ID of this signal in the stack)\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"1234567"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.profiles\.enable



Send continuous profiling data to Grafana Cloud Profiles\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.profiles\.endpoint



Pyroscope push endpoint URL of the Grafana Cloud stack\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"https://profiles-prod-001.grafana.net"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.profiles\.selfScrape



Scrape Alloy’s own pprof endpoints\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.profiles\.selfScrapeAddress



Address of Alloy’s HTTP server, scraped when ` selfScrape ` is set\.



*Type:*
string



*Default:*

```nix
"127.0.0.1:12345"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.profiles\.user



Basic-auth username (the instance ID of this signal in the stack)\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"1234567"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.traces\.enable



Expose OTLP receivers and forward traces to Grafana Cloud Tempo\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.traces\.endpoint



OTLP HTTP endpoint URL of the Grafana Cloud stack\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"https://otlp-gateway-prod-eu-west-0.grafana.net/otlp"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.traces\.otlpGrpcListen



Listen address of the OTLP gRPC receiver\.



*Type:*
string



*Default:*

```nix
"127.0.0.1:4317"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.traces\.otlpHttpListen



Listen address of the OTLP HTTP receiver\.



*Type:*
string



*Default:*

```nix
"127.0.0.1:4318"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.grafanaCloud\.traces\.user



Basic-auth username (the instance ID of this signal in the stack)\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"1234567"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/grafana-cloud)



## services\.llamaServers\.enable



Whether to enable the per-user local model stack (llama-swap behind the Bifrost gateway)\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.anthropicApiKeyFile



File whose whole content is the Anthropic API key\. Required when ` anthropicModels ` is set\.



*Type:*
null or absolute path



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.anthropicModels



Models served by the direct Anthropic API: name clients send ->
Anthropic model id\. Clients still speak OpenAI-compatible to the
gateway and Bifrost translates\. Needs ` anthropicApiKeyFile `\. Name a
` cloudModels ` twin in ` extraFallbacks ` to keep the model reachable
when Anthropic fails or the credit runs out\.



*Type:*
attribute set of string



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  claude-haiku = "claude-haiku-4-5";
}
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.bifrostPackage



The Bifrost gateway package\.



*Type:*
package



*Default:*

```nix
pkgs.bifrost
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.bifrostPort



Loopback port of the Bifrost gateway (its own default, 8080, is often taken)\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
4080
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.bifrostSettings



The generated Bifrost ` config.json `, for inspection\. Secrets appear only as ` env.VAR ` references\.



*Type:*
attribute set of anything *(read only)*



*Default:*
generated from the catalog options

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.cloudModels



Cloud-only models: name clients send -> OpenRouter model id, with no
local server\. ` extraFallbacks ` may name them\.



*Type:*
attribute set of string



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  big-vision = "vendor/some-vision-model";
}
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.datasheetDir



Directory holding Bifrost’s ` pricing.json ` and
` model-parameters.json `\. The default is the sample shipped in the
Bifrost source, so the gateway never fetches them from
getbifrost\.ai\. Null lets Bifrost sync them from the web\.



*Type:*
null or absolute path or string



*Default:*

```nix
"${bifrostPackage.src}/examples/configs/withlocalpricingfiles"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.disableMcpAutoToolInject



Stop Bifrost from adding the tools of ` mcpServers ` to every inference
request\. Set it when coding agents also use the gateway as an MCP
upstream, so each tool appears once\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.environment



Environment of the llama-swap unit, inherited by every llama-server:
backend device selection (` GGML_VK_VISIBLE_DEVICES `,
` HIP_VISIBLE_DEVICES `, ` CUDA_VISIBLE_DEVICES `) and the like\.



*Type:*
attribute set of string



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  GGML_VK_VISIBLE_DEVICES = "0,1";
}
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.extraFallbacks



Extra fallback chains beyond ` openrouterFallbacks `: model name ->
fallback model names\. Targets must be in ` models ` or ` cloudModels `\.
Use this for cloud-to-cloud fallbacks\.



*Type:*
attribute set of list of string



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  big-vision = [
    "other-vision"
  ];
}
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.gatewayPort



Loopback port of the model gateway\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive) *(read only)*



*Default:*

```nix
bifrostPort
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.gatewayResourceControl\.cpuWeight



CPUWeight of the Bifrost gateway unit\. Null keeps systemd’s default\.



*Type:*
null or integer between 1 and 10000 (both inclusive)



*Default:*

```nix
null
```



*Example:*

```nix
80
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.gatewayResourceControl\.memoryHigh



Soft memory ceiling (systemd MemoryHigh) of the Bifrost gateway unit\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"1G"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.gatewayService



systemd user unit of the model gateway, for ` After= ` and ` Wants= `\.



*Type:*
string *(read only)*



*Default:*

```nix
"bifrost.service"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.gatewayURL



OpenAI-compatible base URL of the model gateway\. Clients take it from here\.



*Type:*
string *(read only)*



*Default:*

```nix
"http://127.0.0.1:${toString gatewayPort}/v1"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.llamaCppPackage



The llama-cpp package to use\. Pick the build for the GPU backend (Vulkan, ROCm, CUDA) the models run on\.



*Type:*
package



*Default:*

```nix
pkgs.llama-cpp
```



*Example:*

```nix
llama-cpp-vulkan
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.llamaSwapPackage



The llama-swap package to use\.



*Type:*
package



*Default:*

```nix
pkgs.llama-swap
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.masterKeyFile



File whose whole content is the gateway key\. It is the Bifrost
virtual key and must start with ` sk-bf- `: Bifrost requires it on
inference and MCP routes\. Loopback-only is not an auth model: any
local process could otherwise spend the cloud key\.



*Type:*
null or absolute path



*Default:*

```nix
null
```



*Example:*

```nix
"/run/user/1000/secrets/bifrost-key"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.mcpServers



MCP servers Bifrost fronts\. Each is re-exposed through the gateway
and authenticated to clients by the gateway key\.



*Type:*
attribute set of (submodule)



*Default:*

```nix
{ }
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.mcpServers\.\<name>\.authType



How the upstream takes its key: ` bearer_token ` sends
` Authorization: Bearer <key> `, ` api_key ` sends ` x-api-key `\.



*Type:*
one of “bearer_token”, “api_key”



*Default:*

```nix
"bearer_token"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.mcpServers\.\<name>\.envVar



Environment variable the gateway reads the upstream credential
from\. The runner fills it from ` keyFile ` at start\.



*Type:*
string

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.mcpServers\.\<name>\.keyFile



File whose whole content is the upstream key\.



*Type:*
absolute path

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.mcpServers\.\<name>\.url



Upstream MCP server URL the gateway fronts\.



*Type:*
string

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.models



llama-swap model catalog: the name clients send -> one llama-server\.
At least one model must be resident\.



*Type:*
attribute set of (submodule)



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  small-chat = {
    model = "/var/cache/models/small-chat-Q4_K_M.gguf";
    gpuLayers = 0;
    extraArgs = "-t 8 -c 16384";
    ttl = 1800;
  };
  embedder = {
    kind = "embedding";
    model = pkgs.fetchurl { url = "..."; hash = "..."; };
    devices = [ "Vulkan0" ];
    gpuLayers = 99;
    extraArgs = "--pooling last -c 4096";
  };
}

```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.models\.\<name>\.devices



Devices this model runs on (` -dev `), in llama\.cpp’s naming
(` llama-server --list-devices `)\. Empty leaves llama\.cpp’s
default\. Vulkan numbers devices in enumeration order, which can
differ from DRM card numbering\.



*Type:*
list of string



*Default:*

```nix
[ ]
```



*Example:*

```nix
[
  "Vulkan1"
]
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.models\.\<name>\.extraArgs



Extra llama-server arguments after the generated ones\.



*Type:*
strings concatenated with " "



*Default:*

```nix
""
```



*Example:*

```nix
"-c 8192 -fa on -ctk q8_0 -ctv q8_0"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.models\.\<name>\.gpuLayers



Layers offloaded to the GPU (` -ngl `); 0 keeps the model on the CPU\. Null keeps llama\.cpp’s default\.



*Type:*
null or (unsigned integer, meaning >=0)



*Default:*

```nix
null
```



*Example:*

```nix
99
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.models\.\<name>\.group



` resident `: loaded at start, never evicted\. ` chat `: loaded on
demand, one at a time, swapped out by the next chat request\.



*Type:*
one of “resident”, “chat”



*Default:*

```nix
if kind == "chat" then "chat" else "resident"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.models\.\<name>\.kind



Server mode: ` embedding ` adds ` --embeddings `, ` reranker ` adds
` --reranking --pooling rank `\. Also picks the default group and
the route the warmup request uses\.



*Type:*
one of “chat”, “embedding”, “reranker”



*Default:*

```nix
"chat"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.models\.\<name>\.mmproj



Vision projector GGUF (` --mmproj `)\.



*Type:*
null or package or string



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.models\.\<name>\.model



GGUF weights, passed as ` -m `: a fetched store path or a path
outside the store (large weights are often kept in a cache
directory)\. Null leaves ` -m ` to ` extraArgs `\.



*Type:*
null or package or string



*Default:*

```nix
null
```



*Example:*

```nix
pkgs.fetchurl {
  url = "https://huggingface.co/<owner>/<repo>/resolve/<commit>/<file>.gguf";
  hash = "sha256-...";
}

```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.models\.\<name>\.nCpuMoe



Layers whose MoE expert weights stay in system RAM (` --n-cpu-moe `)\.



*Type:*
null or (unsigned integer, meaning >=0)



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.models\.\<name>\.oomScoreAdjust



oom_score_adj for this model’s llama-server, set with choom\.
Null inherits the unit’s
` services.llamaServers.resourceControl.oomScoreAdjust `\.
Only raising it works: the user manager cannot lower a score\.



*Type:*
null or integer between 0 and 1000 (both inclusive)



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.models\.\<name>\.ttl



Unload after this many idle seconds (0 = never)\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
0
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.openrouterApiKeyFile



File whose whole content is the OpenRouter API key\. Required when
` cloudModels ` or ` openrouterFallbacks ` is set; without either, the
gateway serves the local catalog only\.



*Type:*
null or absolute path



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.openrouterFallbacks



Local model name -> OpenRouter model id\. When the local model fails,
Bifrost retries the request against that OpenRouter model\. Only pair
models whose outputs are interchangeable: an embedding fallback must
keep the same dimension\.



*Type:*
attribute set of string



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  small-chat = "vendor/some-chat-model";
}
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.otel\.enable



Whether to enable OpenTelemetry trace export from Bifrost (its otel plugin)\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.otel\.bearerKeyFile



File holding an API key, sent as the
` authorization: Bearer <key> ` header (what Phoenix expects)\.



*Type:*
null or absolute path



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.otel\.endpoint



OTLP HTTP traces endpoint of the collector\.



*Type:*
string



*Example:*

```nix
"http://127.0.0.1:6006/v1/traces"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.otel\.headerFiles



Header name -> file whose whole content is the header value\. Each
is passed through an env reference, so the value never enters the
store or the config database\.



*Type:*
attribute set of absolute path



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  x-api-key = "/run/secrets/collector-key";
}
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.otel\.project



Project that receives the gateway spans, exported as the
` openinference.project.name ` resource attribute\.



*Type:*
string



*Default:*

```nix
"bifrost"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.otel\.traceType



Span attribute convention\. ` open_inference ` suits Phoenix: it
renders the LLM span with model and token counts\.



*Type:*
one of “genai_extension”, “open_inference”, “vercel”



*Default:*

```nix
"open_inference"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.overflow



Local-first load overflow\. Each key must also be in
` openrouterFallbacks `\. Clients keep the local model name, and Bifrost
uses the OpenRouter model only while the local one is over its cap\.



*Type:*
attribute set of (submodule)



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  embedder = {
    rpm = 30;
    timeout = 60;
  };
}
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.overflow\.\<name>\.rpm



Requests per minute the local model takes before Bifrost
sends the rest to its OpenRouter fallback\. A count of started
requests in a 60 s window, not of requests in flight: size it
to the local model’s measured throughput\.



*Type:*
positive integer, meaning >0

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.overflow\.\<name>\.timeout



Seconds before Bifrost stops waiting on the local model and
fails over\. Null keeps ` requestTimeout `\.



*Type:*
null or (positive integer, meaning >0)



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.requestTimeout



Seconds Bifrost waits on a provider, except for models with an ` overflow ` timeout\.



*Type:*
positive integer, meaning >0



*Default:*

```nix
120
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.resourceControl\.allowedCPUs



cpuset pinning (AllowedCPUs) of llama-swap and its children; null pins nothing\.



*Type:*
null or (list of string)



*Default:*

```nix
null
```



*Example:*

```nix
[
  "8-15"
]
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.resourceControl\.cpuWeight



CPUWeight of llama-swap and its llama-server children\. Null keeps systemd’s default\.



*Type:*
null or integer between 1 and 10000 (both inclusive)



*Default:*

```nix
null
```



*Example:*

```nix
50
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.resourceControl\.memoryHigh



Soft memory ceiling (systemd MemoryHigh) of llama-swap and its
children: past it the kernel reclaims this cgroup first\. A soft
ceiling suits mmap’d weights better than MemoryMax\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"60%"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.resourceControl\.memoryMax



Hard memory ceiling (systemd MemoryMax) of llama-swap and its
children\. Set it above ` memoryHigh ` so mmap’d weights still get
soft reclaim first; past it the kernel OOM-kills inside this
cgroup instead of squeezing the session\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"75%"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.resourceControl\.oomPolicy



systemd OOMPolicy of llama-swap\. ` continue ` keeps llama-swap and
the other model servers running when the kernel kills one server\.



*Type:*
null or one of “continue”, “stop”, “kill”



*Default:*

```nix
null
```



*Example:*

```nix
"continue"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.resourceControl\.oomScoreAdjust



OOM badness of llama-swap and its llama-server children\. A
positive value makes the model servers the preferred victims of
the kernel OOM killer (and earlyoom); llama-swap restarts a
server on the next request\.



*Type:*
null or integer between 0 and 1000 (both inclusive)



*Default:*

```nix
null
```



*Example:*

```nix
300
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.swapPort



Loopback port of llama-swap\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
8710
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.swapSettings



The generated llama-swap configuration, for inspection\.



*Type:*
attribute set of anything *(read only)*



*Default:*
generated from ` models `

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.timeouts



Request timeout in seconds for slow local models without an
OpenRouter fallback (` overflow.<name>.timeout ` covers the others and
wins)\. Bifrost gives each distinct timeout its own local provider\.



*Type:*
attribute set of (positive integer, meaning >0)



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  big-chat = 900;
}
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)



## services\.llamaServers\.validateConfig



Whether to enable checking the generated llama-swap config with ` llama-swap -validate ` at build time\.



*Type:*
boolean



*Default:*

```nix
true
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/home/llama-servers>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/home/llama-servers)


