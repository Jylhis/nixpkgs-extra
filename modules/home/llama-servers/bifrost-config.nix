# Renders the Bifrost config.json for services.llamaServers. Clients send a
# bare model name; one global routing rule per name picks the provider.
# Providers:
#   local         llama-swap (a keyless custom openai provider)
#   local-<n>s    the same llama-swap with an <n> second request timeout, one
#                 per distinct overflow or `timeouts` value (Bifrost times out
#                 per provider)
#   openrouter    the cloud egress, present only when some model routes to
#                 it; its key is read from OPENROUTER_API_KEY
#   anthropic     the direct Anthropic API, present only when anthropicModels
#                 is set; its key is read from ANTHROPIC_API_KEY
# Secrets never appear here: values are `env.VAR` references the runner fills.
{ lib }:
let
  slug = lib.replaceStrings [ "." "/" "_" ] [ "-" "-" "-" ];
  celString = builtins.toJSON;

  # The header an upstream MCP server reads its credential from.
  headerName =
    s:
    {
      bearer_token = "Authorization";
      api_key = "x-api-key";
    }
    .${s.authType or "bearer_token"};

  # The MCP client for each gateway server (the module's mcpServers). Each
  # header value is an env reference; the runner fills it with the complete
  # header value (see headerValue).
  mcpClients = lib.mapAttrsToList (
    name: s: {
      inherit name;
      connection_type = "http";
      connection_string = s.url;
      auth_type = "headers";
      headers.${headerName s} = "env.${s.envVar}";
      tools_to_execute = [ "*" ];
    }
  );
in
{
  inherit mcpClients;

  # The value the runner writes to the env file for that header.
  headerValue =
    s: key: if (s.authType or "bearer_token") == "bearer_token" then "Bearer ${key}" else key;

  # cloudModels: name -> OpenRouter id (no local twin). anthropicModels: name
  # -> Anthropic model id. openrouterFallbacks: local name -> OpenRouter id.
  # overflow: local name -> { rpm, timeout }. timeouts: local name -> request
  # seconds for models outside overflow (overflow wins). otel headers: name ->
  # env var name.
  render =
    {
      swapPort,
      localModels,
      cloudModels ? { },
      anthropicModels ? { },
      timeouts ? { },
      openrouterFallbacks ? { },
      overflow ? { },
      extraFallbacks ? { },
      mcpServers ? { },
      otel ? null,
      timeout ? 120,
      # Bifrost is often also the /mcp upstream of coding agents; injecting
      # every MCP tool into each inference request would then double them.
      disableMcpAutoToolInject ? false,
      # A directory holding pricing.json and model-parameters.json. Set, the
      # datasheets load from it and the gateway never calls getbifrost.ai.
      datasheetDir ? null,
    }:
    let
      localNames = lib.attrNames localModels;
      exposed = lib.sort lib.lessThan (
        localNames ++ lib.attrNames cloudModels ++ lib.attrNames anthropicModels
      );

      overflowTimeout = name: overflow.${name}.timeout or timeouts.${name} or null;
      providerOf =
        name:
        let
          t = overflowTimeout name;
        in
        if t == null then "local" else "local-${toString t}s";
      distinctTimeouts = lib.unique (lib.filter (t: t != null) (map overflowTimeout localNames));

      refOf =
        name:
        if cloudModels ? ${name} then
          "openrouter/${cloudModels.${name}}"
        else if anthropicModels ? ${name} then
          "anthropic/${anthropicModels.${name}}"
        else if localModels ? ${name} then
          "${providerOf name}/${name}"
        else
          throw "bifrost: fallback target ${name} is not in the catalog";

      localProvider = seconds: names: {
        keys = [
          {
            name = "llama-swap";
            value = "none";
            models = names;
            weight = 1;
          }
        ];
        network_config = {
          base_url = "http://127.0.0.1:${toString swapPort}";
          default_request_timeout_in_seconds = seconds;
          max_retries = 0;
        };
        custom_provider_config = {
          base_provider_type = "openai";
          is_key_less = true;
        };
      };
      namesOn = providerName: lib.filter (n: providerOf n == providerName) localNames;
      localProviders = lib.listToAttrs (
        map (
          t: lib.nameValuePair "local-${toString t}s" (localProvider t (namesOn "local-${toString t}s"))
        ) distinctTimeouts
      );
      plainLocal = namesOn "local";

      orModels = lib.unique (lib.attrValues openrouterFallbacks ++ lib.attrValues cloudModels);

      target = name: {
        provider =
          if cloudModels ? ${name} then
            "openrouter"
          else if anthropicModels ? ${name} then
            "anthropic"
          else
            providerOf name;
        model = cloudModels.${name} or anthropicModels.${name} or name;
        weight = 1;
      };
      fallbacksOf =
        name:
        lib.optional (openrouterFallbacks ? ${name}) "openrouter/${openrouterFallbacks.${name}}"
        ++ map refOf (extraFallbacks.${name} or [ ]);

      # Past `rpm` requests a minute the model's rate limit reads 100 percent;
      # the first rule then sends the request to the OpenRouter twin.
      rulesFor =
        i: name:
        let
          fallbacks = fallbacksOf name;
        in
        lib.optional (overflow ? ${name}) {
          id = "overflow-${slug name}";
          name = "${name} overflow";
          enabled = true;
          cel_expression = "model == ${celString name} && request >= 100.0";
          priority = 10 * i;
          targets = [
            {
              provider = "openrouter";
              model = openrouterFallbacks.${name};
              weight = 1;
            }
          ];
        }
        ++ [
          (
            {
              id = "route-${slug name}";
              inherit name;
              enabled = true;
              cel_expression = "model == ${celString name}";
              priority = 10 * i + 1;
              targets = [ (target name) ];
            }
            // lib.optionalAttrs (fallbacks != [ ]) { inherit fallbacks; }
          )
        ];
    in
    {
      "$schema" = "https://www.getbifrost.ai/schema";
      # Nix stays authoritative: every start rewrites the sections below in the
      # config store, so a UI edit does not outlive a restart.
      source_of_truth = "config.json";
      client = {
        enforce_auth_on_inference = true;
        enable_logging = false;
        whitelisted_routes = [ "/metrics" ];
      };
      config_store = {
        enabled = true;
        type = "sqlite";
        config.path = "./config.db";
      };
      logs_store.enabled = false;
      framework.pricing = {
        mcp_library_sync_interval = 0;
      }
      // lib.optionalAttrs (datasheetDir != null) {
        pricing_url = "file://${datasheetDir}/pricing.json";
        model_parameters_url = "file://${datasheetDir}/model-parameters.json";
      };

      providers =
        lib.optionalAttrs (plainLocal != [ ]) { local = localProvider timeout plainLocal; }
        // localProviders
        // lib.optionalAttrs (orModels != [ ]) {
          openrouter = {
            keys = [
              {
                name = "openrouter";
                value = "env.OPENROUTER_API_KEY";
                models = orModels;
                weight = 1;
              }
            ];
            network_config = {
              default_request_timeout_in_seconds = timeout;
              max_retries = 0;
            };
          };
        }
        // lib.optionalAttrs (anthropicModels != { }) {
          anthropic = {
            keys = [
              {
                name = "anthropic";
                value = "env.ANTHROPIC_API_KEY";
                models = lib.unique (lib.attrValues anthropicModels);
                weight = 1;
              }
            ];
            network_config = {
              default_request_timeout_in_seconds = timeout;
              max_retries = 0;
            };
          };
        };

      governance = {
        # The dashboard admin is declared here: the UI cannot save it,
        # because a PUT /api/config refuses the file:// pricing URLs.
        auth_config = {
          admin_username = "env.BIFROST_ADMIN_USERNAME";
          admin_password = "env.BIFROST_ADMIN_PASSWORD";
          is_enabled = true;
        };
        virtual_keys = [
          {
            id = "main";
            name = "main";
            value = "env.BIFROST_VK";
            is_active = true;
            allow_all_providers = true;
            mcp_configs = map (n: {
              mcp_client_name = n;
              tools_to_execute = [ "*" ];
            }) (lib.attrNames mcpServers);
          }
        ];
        routing_rules = lib.concatLists (lib.imap1 rulesFor exposed);
        rate_limits = lib.mapAttrsToList (n: o: {
          id = "rpm-${slug n}";
          request_max_limit = o.rpm;
          request_reset_duration = "1m";
        }) overflow;
        model_configs = lib.mapAttrsToList (n: _: {
          id = "rpm-${slug n}";
          model_name = n;
          rate_limit_id = "rpm-${slug n}";
        }) overflow;
      };

      mcp = {
        client_configs = mcpClients mcpServers;
      }
      // lib.optionalAttrs disableMcpAutoToolInject {
        tool_manager_config.disable_auto_tool_inject = true;
      };

      plugins = [
        {
          name = "telemetry";
          enabled = true;
          config = { };
        }
      ]
      ++ lib.optional (otel != null) {
        name = "otel";
        enabled = true;
        config = {
          collector_url = otel.endpoint;
          protocol = "http";
          trace_type = otel.traceType;
          service_name = "bifrost";
          headers = lib.mapAttrs (_: v: "env.${v}") otel.headers;
        };
      };
    };
}
