{ pkgs, ... }:

let
  # ---------------------------------------------------------------------------
  # Third-party plugins not packaged in nixvim
  # ---------------------------------------------------------------------------
  # alabaster.nvim — minimalist colorscheme ported from Sublime Text
  alabaster-nvim = pkgs.vimUtils.buildVimPlugin {
    pname = "alabaster-nvim";
    version = "unstable-2026-04-14";
    src = pkgs.fetchFromGitHub {
      owner = "dchinmay2";
      repo = "alabaster.nvim";
      rev = "b902c73fabefc13583bfc0c18b28950ea8f6244f";
      hash = "sha256-Rp/nl5dlz55aChrYUL7ir3XtWDFFS99CHS3l3FoCI7c=";
    };
  };
in
{
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = false;
    vimAlias = false;
    withRuby = false;
    withPython3 = false;

    # =========================================================================
    # Global variables
    # =========================================================================
    globals = {
      mapleader = " ";
      maplocalleader = " ";
    };

    # =========================================================================
    # Options (`:h option-list`)
    # =========================================================================
    opts = {
      # -- Line numbers & sign column
      number = true;
      relativenumber = false;
      signcolumn = "yes";

      # -- Indentation (2-space default; per-filetype overrides in autoCmd below)
      expandtab = true;
      tabstop = 2;
      softtabstop = 2;
      shiftwidth = 2;
      smartindent = true;
      autoindent = true;

      # -- Search
      hlsearch = true;
      incsearch = true;
      ignorecase = true;
      smartcase = true;

      # -- Folding: unfolded by default; nvim-ufo provides the folds.
      foldenable = true;
      foldlevel = 99;
      foldlevelstart = 99;
      foldcolumn = "1";

      # -- UI
      mouse = "a";
      termguicolors = true;
      cursorline = true;
      showmode = false; # lualine renders the mode
      cmdheight = 1;
      laststatus = 3; # global statusline
      splitbelow = true;
      splitright = true;
      scrolloff = 8;
      sidescrolloff = 8;

      # -- Completion & responsiveness
      completeopt = "menuone,noselect,noinsert";
      updatetime = 300;

      # -- Files / buffers
      hidden = true;
      swapfile = false;
      undofile = true;
      clipboard = "unnamedplus";
      exrc = true; # load project-local .nvim.lua (prompts :trust on first use)

      # -- Display
      wrap = false;
      listchars = "tab:▸ ,eol:¬,trail:·,nbsp:␣";
    };

    # =========================================================================
    # Colorscheme
    # =========================================================================
    colorscheme = "alabaster";

    # =========================================================================
    # Plugins
    # =========================================================================
    plugins = {

      # -----------------------------------------------------------------------
      # Syntax & structural editing
      # -----------------------------------------------------------------------
      treesitter = {
        enable = true;
        folding.enable = true; # expose fold ranges for nvim-ufo
        settings = {
          ensure_installed = "all";
          highlight.enable = true;
          indent.enable = true;
        };
      };

      # -----------------------------------------------------------------------
      # File explorer (AstroNvim-style sidebar)
      # -----------------------------------------------------------------------
      neo-tree = {
        enable = true;
        settings = {
          close_if_last_window = true;
          filesystem = {
            follow_current_file.enabled = true;
            use_libuv_file_watcher = true;
          };
          window = {
            width = 30;
            # AstroNvim-style vim navigation: `h` collapses or moves to parent,
            # `l` expands a directory, dives into first child, or opens a file.
            mappings = {
              h.__raw = ''
                function(state)
                  local node = state.tree:get_node()
                  if (node.type == "directory" or node:has_children()) and node:is_expanded() then
                    state.commands.toggle_node(state)
                  else
                    require("neo-tree.ui.renderer").focus_node(state, node:get_parent_id())
                  end
                end
              '';
              l.__raw = ''
                function(state)
                  local node = state.tree:get_node()
                  if node.type == "directory" then
                    if not node:is_expanded() then
                      state.commands.toggle_node(state)
                    elseif node:has_children() then
                      require("neo-tree.ui.renderer").focus_node(state, node:get_child_ids()[1])
                    end
                  else
                    state.commands.open(state)
                  end
                end
              '';
            };
          };
        };
      };

      # -----------------------------------------------------------------------
      # Fuzzy finder
      # -----------------------------------------------------------------------
      telescope = {
        enable = true;
        settings.defaults = {
          path_display = [ "truncate" ];
          sorting_strategy = "ascending";
          # Wide horizontal layout so the preview pane is always visible.
          layout_strategy = "horizontal";
          layout_config = {
            prompt_position = "top";
            width = 0.9;
            height = 0.85;
            horizontal = {
              preview_width = 0.55;
              preview_cutoff = 80; # hide preview only if terminal is < 80 cols
            };
          };
        };
        keymaps = {
          "<leader>ff" = "find_files";
          "<leader>fw" = "live_grep";
          "<leader>fb" = "buffers";
          "<leader>fc" = "git_commits";
        };
      };
      # File-type icons used by neo-tree, telescope, bufferline, lualine.
      # Enable explicitly to silence the auto-enable deprecation warning.
      web-devicons.enable = true;

      # -----------------------------------------------------------------------
      # LSP
      # -----------------------------------------------------------------------
      lsp = {
        enable = true;
        servers = {
          bashls.enable = true;
          clangd = {
            enable = true;
            cmd = [
              "clangd"
              "--background-index"
              "--clang-tidy"
              "--header-insertion=iwyu"
            ];
          };
          gopls.enable = true;
          lua_ls = {
            enable = true;
            settings.Lua.diagnostics.globals = [ "vim" ];
          };
          marksman.enable = true;
          nil_ls.enable = true;
          pyright.enable = true;
          # rust-analyzer relies on the surrounding shell's PATH for cargo /
          # rustc / rustfmt / clippy — pin those per project via a fenix
          # devShell and launch `nvim` from inside `nix develop` so formatting
          # and lints match the project's toolchain. Without a devShell active
          # the LSP will fail to start (`rustc` not found); that's intended.
          # The install* = false flags suppress nixvim's "you should bundle
          # cargo/rustc" warnings — we deliberately want them PATH-resolved.
          rust_analyzer = {
            enable = true;
            installCargo = false;
            installRustc = false;
          };
          yamlls.enable = true;
        };
      };
      # Non-intrusive LSP progress notifications in the bottom-right corner.
      fidget.enable = true;

      # -----------------------------------------------------------------------
      # Completion + snippets
      # -----------------------------------------------------------------------
      blink-cmp = {
        enable = true;
        settings = {
          keymap.preset = "default"; # Tab accepts; <C-n>/<C-p> cycle
          sources.default = [
            "lsp"
            "path"
            "snippets"
            "buffer"
          ];
          signature.enabled = true;
          appearance.nerd_font_variant = "normal";
          completion = {
            documentation.auto_show = true;
            accept.auto_brackets.enabled = true;
          };
        };
      };
      luasnip.enable = true;

      # -----------------------------------------------------------------------
      # Formatting (format-on-save for every configured formatter)
      # -----------------------------------------------------------------------
      conform-nvim = {
        enable = true;
        settings = {
          # Skip when vim.g.disable_autoformat (session) or
          # vim.b.disable_autoformat (buffer) is set. Toggle with the
          # :FormatDisable[!] / :FormatEnable user commands defined below.
          format_on_save.__raw = ''
            function(bufnr)
              if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
                return
              end
              return { lsp_format = "fallback", timeout_ms = 1000 }
            end
          '';
          formatters_by_ft = {
            c = [ "clang_format" ];
            cpp = [ "clang_format" ];
            go = [ "gofmt" ];
            lua = [ "stylua" ];
            markdown = [ "prettier" ];
            nix = [ "nixfmt" ];
            python = [ "black" ];
            sh = [ "shfmt" ];
            yaml = [ "prettier" ];
            # Rust formatting happens via rust-analyzer (LSP fallback).
            "_" = [
              "trim_whitespace"
              "trim_newlines"
            ]; # all filetypes
          };
        };
      };

      # -----------------------------------------------------------------------
      # Keymap discovery (AstroNvim's signature feature)
      # -----------------------------------------------------------------------
      which-key = {
        enable = true;
        settings = {
          preset = "modern";
          spec = [
            {
              __unkeyed-1 = "<leader>b";
              group = "buffer";
            }
            {
              __unkeyed-1 = "<leader>f";
              group = "find";
            }
            {
              __unkeyed-1 = "<leader>g";
              group = "git";
            }
            {
              __unkeyed-1 = "<leader>l";
              group = "lsp";
            }
            {
              __unkeyed-1 = "<leader>t";
              group = "terminal";
            }
            {
              __unkeyed-1 = "<leader>x";
              group = "diagnostics";
            }
          ];
        };
      };

      # -----------------------------------------------------------------------
      # Status line
      # -----------------------------------------------------------------------
      lualine = {
        enable = true;
        settings = {
          options = {
            theme = "auto";
            globalstatus = true;
            section_separators = {
              left = "";
              right = "";
            };
            component_separators = {
              left = "│";
              right = "│";
            };
          };
          sections = {
            lualine_a = [ "mode" ];
            lualine_b = [
              "branch"
              "diff"
              "diagnostics"
            ];
            lualine_c = [
              {
                __unkeyed-1 = "filename";
                path = 1;
              }
            ];
            lualine_x = [ "filetype" ];
            lualine_y = [ "progress" ];
            lualine_z = [ "location" ];
          };
        };
      };

      # -----------------------------------------------------------------------
      # Buffer tab bar
      # -----------------------------------------------------------------------
      bufferline = {
        enable = true;
        settings.options = {
          diagnostics = "nvim_lsp";
          always_show_bufferline = true;
          show_buffer_close_icons = true;
          separator_style = "slant";
          offsets = [
            {
              filetype = "neo-tree";
              text = "File Explorer";
              highlight = "Directory";
              text_align = "center";
            }
          ];
        };
      };

      # -----------------------------------------------------------------------
      # Git integration
      # -----------------------------------------------------------------------
      gitsigns = {
        enable = true;
        settings = {
          signs = {
            add.text = "▎";
            change.text = "▎";
            delete.text = "";
            topdelete.text = "";
            changedelete.text = "▎";
            untracked.text = "▎";
          };
          current_line_blame = false; # toggle with <leader>gb
        };
      };

      # -----------------------------------------------------------------------
      # Editor ergonomics
      # -----------------------------------------------------------------------
      ts-comments.enable = true; # gc/gcc/gbc via treesitter
      nvim-autopairs.enable = true;
      indent-blankline = {
        enable = true;
        settings = {
          indent.char = "│";
          scope.enabled = true;
        };
      };
      flash = {
        enable = true;
        settings.modes.search.enabled = false; # don't hijack `/`
      };

      # -----------------------------------------------------------------------
      # Folding (managed with treesitter + LSP providers)
      # -----------------------------------------------------------------------
      nvim-ufo.enable = true;

      # -----------------------------------------------------------------------
      # Diagnostics viewer
      # -----------------------------------------------------------------------
      trouble.enable = true;

      # -----------------------------------------------------------------------
      # Symbol outline (AstroNvim's <leader>lS navigator)
      # -----------------------------------------------------------------------
      aerial = {
        enable = true;
        settings = {
          attach_mode = "global";
          backends = [
            "lsp"
            "treesitter"
            "markdown"
            "man"
          ];
          layout = {
            min_width = 28;
            default_direction = "prefer_right";
          };
          show_guides = true;
          filter_kind = false; # show every symbol kind by default
        };
      };

      # -----------------------------------------------------------------------
      # Integrated terminal (AstroNvim-style floats/splits)
      # -----------------------------------------------------------------------
      toggleterm = {
        enable = true;
        settings = {
          size.__raw = ''
            function(term)
              if term.direction == "horizontal" then
                return 15
              elseif term.direction == "vertical" then
                return math.floor(vim.o.columns * 0.4)
              end
            end
          '';
          open_mapping = "[[<F7>]]"; # <F7> toggles the default terminal
          shade_terminals = true;
          start_in_insert = true;
          persist_size = true;
          direction = "float";
          float_opts.border = "curved";
        };
      };
    };

    # =========================================================================
    # Non-nixvim plugins
    # =========================================================================
    extraPlugins = [ alabaster-nvim ];

    # =========================================================================
    # Runtime dependencies added to nvim's PATH
    # =========================================================================
    # ripgrep powers telescope's live_grep; fd speeds up find_files.
    extraPackages = with pkgs; [
      ripgrep
      fd
    ];

    # =========================================================================
    # Keymaps (non-LSP; LSP keymaps are attached per-buffer in extraConfigLua)
    # =========================================================================
    keymaps = [
      # ---- General ----------------------------------------------------------
      {
        mode = "n";
        key = "<Esc>";
        action = "<cmd>nohlsearch<cr>";
        options.desc = "Clear search highlight";
      }
      {
        mode = "n";
        key = "<C-s>";
        action = "<cmd>w<cr>";
        options.desc = "Save file";
      }
      {
        mode = "i";
        key = "<C-s>";
        action = "<Esc><cmd>w<cr>";
        options.desc = "Save file";
      }

      # ---- Window navigation (Ctrl+hjkl, wraps at screen edges) -------------
      # If wincmd <dir> doesn't move us (edge of layout), jump all the way
      # to the opposite edge with `999 wincmd <opposite>` — effectively wrap.
      {
        mode = "n";
        key = "<C-h>";
        action.__raw = ''
          function()
            local cur = vim.api.nvim_get_current_win()
            vim.cmd.wincmd("h")
            if vim.api.nvim_get_current_win() == cur then vim.cmd("999 wincmd l") end
          end
        '';
        options.desc = "Window left (wraps)";
      }
      {
        mode = "n";
        key = "<C-j>";
        action.__raw = ''
          function()
            local cur = vim.api.nvim_get_current_win()
            vim.cmd.wincmd("j")
            if vim.api.nvim_get_current_win() == cur then vim.cmd("999 wincmd k") end
          end
        '';
        options.desc = "Window down (wraps)";
      }
      {
        mode = "n";
        key = "<C-k>";
        action.__raw = ''
          function()
            local cur = vim.api.nvim_get_current_win()
            vim.cmd.wincmd("k")
            if vim.api.nvim_get_current_win() == cur then vim.cmd("999 wincmd j") end
          end
        '';
        options.desc = "Window up (wraps)";
      }
      {
        mode = "n";
        key = "<C-l>";
        action.__raw = ''
          function()
            local cur = vim.api.nvim_get_current_win()
            vim.cmd.wincmd("l")
            if vim.api.nvim_get_current_win() == cur then vim.cmd("999 wincmd h") end
          end
        '';
        options.desc = "Window right (wraps)";
      }

      # ---- Splits -----------------------------------------------------------
      {
        mode = "n";
        key = "<leader>|";
        action = "<cmd>vsplit<cr>";
        options.desc = "Vertical split";
      }
      {
        mode = "n";
        key = "<leader>\\";
        action = "<cmd>split<cr>";
        options.desc = "Horizontal split";
      }
      {
        mode = "n";
        key = "<leader>-";
        action = "<cmd>split<cr>";
        options.desc = "Horizontal split";
      }

      # ---- Terminal (toggleterm) --------------------------------------------
      # <F7> is set as the global open_mapping in the toggleterm settings.
      {
        mode = "n";
        key = "<leader>tf";
        action = "<cmd>ToggleTerm direction=float<cr>";
        options.desc = "Float terminal";
      }
      {
        mode = "n";
        key = "<leader>th";
        action = "<cmd>ToggleTerm direction=horizontal<cr>";
        options.desc = "Horizontal terminal";
      }
      {
        mode = "n";
        key = "<leader>tv";
        action = "<cmd>ToggleTerm direction=vertical<cr>";
        options.desc = "Vertical terminal";
      }
      # Press <Esc><Esc> inside a terminal to drop to normal mode
      {
        mode = "t";
        key = "<Esc><Esc>";
        action = "<C-\\><C-n>";
        options.desc = "Exit terminal mode";
      }

      # ---- Buffers (AstroNvim-style) ----------------------------------------
      {
        mode = "n";
        key = "]b";
        action = "<cmd>BufferLineCycleNext<cr>";
        options.desc = "Next buffer";
      }
      {
        mode = "n";
        key = "[b";
        action = "<cmd>BufferLineCyclePrev<cr>";
        options.desc = "Previous buffer";
      }
      {
        mode = "n";
        key = ">b";
        action = "<cmd>BufferLineMoveNext<cr>";
        options.desc = "Move buffer right";
      }
      {
        mode = "n";
        key = "<b";
        action = "<cmd>BufferLineMovePrev<cr>";
        options.desc = "Move buffer left";
      }
      {
        mode = "n";
        key = "<leader>c";
        action = "<cmd>bdelete<cr>";
        options.desc = "Close buffer";
      }
      {
        mode = "n";
        key = "<leader>C";
        action = "<cmd>bdelete!<cr>";
        options.desc = "Force close buffer";
      }
      {
        mode = "n";
        key = "<leader>bp";
        action = "<cmd>BufferLineTogglePin<cr>";
        options.desc = "Toggle pin";
      }
      {
        mode = "n";
        key = "<leader>bP";
        action = "<cmd>BufferLineGroupClose ungrouped<cr>";
        options.desc = "Close unpinned buffers";
      }

      # ---- File explorer (neo-tree) -----------------------------------------
      {
        mode = "n";
        key = "<leader>e";
        action = "<cmd>Neotree toggle<cr>";
        options.desc = "Toggle file explorer";
      }
      {
        mode = "n";
        key = "<leader>o";
        action = "<cmd>Neotree focus<cr>";
        options.desc = "Focus file explorer";
      }

      # ---- Folding (nvim-ufo) -----------------------------------------------
      {
        mode = "n";
        key = "zR";
        action.__raw = "function() require('ufo').openAllFolds()  end";
        options.desc = "Open all folds";
      }
      {
        mode = "n";
        key = "zM";
        action.__raw = "function() require('ufo').closeAllFolds() end";
        options.desc = "Close all folds";
      }

      # ---- Git (gitsigns) ---------------------------------------------------
      {
        mode = "n";
        key = "]h";
        action.__raw = "function() require('gitsigns').nav_hunk('next') end";
        options.desc = "Next git hunk";
      }
      {
        mode = "n";
        key = "[h";
        action.__raw = "function() require('gitsigns').nav_hunk('prev') end";
        options.desc = "Previous git hunk";
      }
      {
        mode = "n";
        key = "<leader>gp";
        action = "<cmd>Gitsigns preview_hunk<cr>";
        options.desc = "Preview hunk";
      }
      {
        mode = "n";
        key = "<leader>gs";
        action = "<cmd>Gitsigns stage_hunk<cr>";
        options.desc = "Stage hunk";
      }
      {
        mode = "n";
        key = "<leader>gr";
        action = "<cmd>Gitsigns reset_hunk<cr>";
        options.desc = "Reset hunk";
      }
      {
        mode = "n";
        key = "<leader>gb";
        action = "<cmd>Gitsigns toggle_current_line_blame<cr>";
        options.desc = "Toggle line blame";
      }

      # ---- LSP pickers (telescope-backed) -----------------------------------
      {
        mode = "n";
        key = "<leader>lS";
        action = "<cmd>AerialToggle<cr>";
        options.desc = "Symbol outline (aerial)";
      }
      {
        mode = "n";
        key = "<leader>lR";
        action = "<cmd>Telescope lsp_references<cr>";
        options.desc = "References of symbol under cursor";
      }
      {
        mode = "n";
        key = "<leader>lD";
        action = "<cmd>Telescope diagnostics<cr>";
        options.desc = "Search diagnostics";
      }

      # ---- Diagnostics ------------------------------------------------------
      {
        mode = "n";
        key = "[d";
        action.__raw = "vim.diagnostic.goto_prev";
        options.desc = "Previous diagnostic";
      }
      {
        mode = "n";
        key = "]d";
        action.__raw = "vim.diagnostic.goto_next";
        options.desc = "Next diagnostic";
      }
      {
        mode = "n";
        key = "<leader>ld";
        action.__raw = "vim.diagnostic.open_float";
        options.desc = "Hover diagnostic";
      }
      {
        mode = "n";
        key = "<leader>xx";
        action = "<cmd>Trouble diagnostics toggle<cr>";
        options.desc = "Workspace diagnostics";
      }
      {
        mode = "n";
        key = "<leader>xX";
        action = "<cmd>Trouble diagnostics toggle filter.buf=0<cr>";
        options.desc = "Buffer diagnostics";
      }
      {
        mode = "n";
        key = "<leader>xq";
        action = "<cmd>Trouble qflist toggle<cr>";
        options.desc = "Quickfix list";
      }

      # ---- Reselect visual block after indent -------------------------------
      {
        mode = "v";
        key = "<";
        action = "<gv";
      }
      {
        mode = "v";
        key = ">";
        action = ">gv";
      }
    ];

    # =========================================================================
    # Extra lua: LSP buffer-local keymaps + yank highlight
    # =========================================================================
    extraConfigLua = ''
      -- Buffer-local keymaps attached when an LSP client connects.
      vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(args)
          local map = function(lhs, rhs, desc)
            vim.keymap.set('n', lhs, rhs, { buffer = args.buf, desc = 'LSP: ' .. desc })
          end

          map('gd',         vim.lsp.buf.definition,      'Goto definition')
          map('gD',         vim.lsp.buf.declaration,     'Goto declaration')
          map('gi',         vim.lsp.buf.implementation,  'Goto implementation')
          map('gr',         vim.lsp.buf.references,      'Goto references')
          map('gy',         vim.lsp.buf.type_definition, 'Goto type definition')
          map('K',          vim.lsp.buf.hover,           'Hover documentation')
          map('<leader>la', vim.lsp.buf.code_action,     'Code action')
          map('<leader>lr', vim.lsp.buf.rename,          'Rename symbol')
          map('<leader>lf', function() vim.lsp.buf.format { async = true } end, 'Format buffer')

          -- Enable inlay hints where supported.
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client and client.server_capabilities.inlayHintProvider then
            vim.lsp.inlay_hint.enable(true, { bufnr = args.buf })
          end
        end,
      })

      -- Toggle conform's format-on-save. Bang variant scopes to the buffer;
      -- a project-wide opt-out can live in a `.nvim.lua` (exrc) file:
      --   vim.g.disable_autoformat = true
      vim.api.nvim_create_user_command('FormatDisable', function(args)
        if args.bang then
          vim.b.disable_autoformat = true
        else
          vim.g.disable_autoformat = true
        end
      end, { desc = 'Disable autoformat-on-save', bang = true })

      vim.api.nvim_create_user_command('FormatEnable', function()
        vim.b.disable_autoformat = false
        vim.g.disable_autoformat = false
      end, { desc = 'Re-enable autoformat-on-save' })
    '';

    # =========================================================================
    # Autocommands
    # =========================================================================
    autoCmd = [
      # Highlight yanked region briefly
      {
        event = [ "TextYankPost" ];
        callback.__raw = ''
          function() vim.highlight.on_yank { higroup = "IncSearch", timeout = 150 } end
        '';
      }
      # 4-space indent for C++ / Python / Rust
      {
        event = [ "FileType" ];
        pattern = [
          "cpp"
          "python"
          "rust"
        ];
        callback.__raw = ''
          function()
            vim.opt_local.tabstop = 4
            vim.opt_local.softtabstop = 4
            vim.opt_local.shiftwidth = 4
          end
        '';
      }
      # Go uses tabs
      {
        event = [ "FileType" ];
        pattern = "go";
        callback.__raw = "function() vim.opt_local.expandtab = false end";
      }
    ];
  };
}
