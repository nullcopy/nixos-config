{ ... }:

# opencode (https://opencode.ai) wired up to the local ollama service
# defined in hosts/wisp/ollama.nix, via home-manager's programs.opencode
# module: it installs the package and renders `settings` to
# ~/.config/opencode/opencode.json (adding the `$schema` key itself).
#
# Pulling models is an out-of-band step (not declarative): once this
# config is active, run `ollama pull <model>` for whichever entry under
# `provider.ollama.models` you intend to use. Selecting a model that
# isn't pulled yet fails at request time, not at config-load time.

{
  programs.opencode = {
    enable = true;

    settings = {
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

      # Default model selector is "<providerID>/<modelID>"; the modelID is
      # the ollama tag (e.g. "qwen3-coder:30b") — same string you'd pass to
      # `ollama pull`.
      model = "ollama/qwen3.6:35b";
    };
  };
}
