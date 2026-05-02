{ pkgs, ... }:

# opencode (https://opencode.ai) wired up to the local ollama service
# defined in hosts/wisp/ollama.nix. opencode has no home-manager module
# in nixpkgs, so we install the package and drop the JSON config under
# ~/.config/opencode/opencode.json directly.
#
# Pulling models is an out-of-band step (not declarative): once this
# config is active, run `ollama pull <model>` for whichever entry under
# `provider.ollama.models` you intend to use. Selecting a model that
# isn't pulled yet fails at request time, not at config-load time.

let
  # opencode's model selector is "<providerID>/<modelID>". The provider
  # ID below is "ollama", and the modelID is the ollama tag (e.g.
  # "qwen3-coder:30b") — same string you'd pass to `ollama pull`.
  defaultModel = "ollama/qwen3.6:35b";

  opencodeConfig = {
    "$schema" = "https://opencode.ai/config.json";

    # opencode talks to ollama via its OpenAI-compatible endpoint
    # (/v1). Anything ollama hosts is reachable as long as it's been
    # pulled locally.
    provider.ollama = {
      npm = "@ai-sdk/openai-compatible";
      name = "Ollama (local)";
      options.baseURL = "http://127.0.0.1:11434/v1";
      # Add/remove entries as you pull models. The keys must match the
      # exact ollama tag.
      models = {
        "llama3.2:3b".name = "Llama 3.2 3B";
        "qwen2.5-coder:32b".name = "Qwen2.5 Coder 32B";
        "gpt-oss:20b".name = "GPT-OSS 20B";
        "gpt-oss:120b".name = "GPT-OSS 120B";
        "granite4.1:30b".name = "Granite 4.1 30B";
        "qwen3-coder:30b".name = "Qwen3 Coder 30B";
        "qwen3.6:35b".name = "Qwen 3.6 35B";
      };
    };

    model = defaultModel;
  };
in
{
  home.packages = [ pkgs.opencode ];

  xdg.configFile."opencode/opencode.json".source =
    (pkgs.formats.json { }).generate "opencode.json"
      opencodeConfig;
}
