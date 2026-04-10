{ pkgs, ... }:

{
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withRuby = false;
    withPython3 = false;

    ## ----- globals --------------------------------------------------------------
    globals = {
      mapleader = " ";
      # git-blame
      gitblame_clipboard_register = "*";
      # ctrlp
      ctrlp_max_files = 0;
      ctrlp_user_command.__raw = "{ '.git/', 'git --git-dir=%s/.git ls-files -oc --exclude-standard' }";
      ctrlp_custom_ignore.__raw = ''
        {
          dir = [[\v[\/](\.(git|hg|svn|stack_work)|(target|dist|depends))$]],
          file = [[\v\.(o|dyn_o|so|dyn_so|hi|dyn_hi)$]],
        }
      '';
      # haskell
      haddock_docdir = "dist/doc/html";
      haskell_tools.__raw = ''
        {
          hls = {
            default_settings = {
              haskell = {
                formattingProvider = "ormolu",
              },
            },
          },
        }
      '';
    };

    ## ----- options ---------------------------------------------------------------
    opts = {
      modelines = 0;
      number = true;
      signcolumn = "yes";
      showmode = true;
      cmdheight = 1;
      ruler = true;
      listchars = "tab:▸ ,eol:¬";
      list = false;
      hlsearch = true;
      mouse = "";
      smartcase = true;
      smarttab = true;
      smartindent = true;
      autoindent = true;
      fileencodings = "ucs-bom,utf-8,default,latin1";
      tags = "tags;HOME";
      exrc = true;
      secure = true;
      completeopt = "menuone,noselect,noinsert";
      updatetime = 300;
      expandtab = true;
      tabstop = 2;
      softtabstop = 2;
      shiftwidth = 2;
      clipboard = "unnamedplus";
      laststatus = 2;
      statusline = "%f[%{strlen(&fenc)?&fenc:'none'},%{&ff}]%h%m%r%y%=%c,%l/%L %P";
      background = "dark";
      wildmode = "longest,list,full";
      wildmenu = true;
    };

    ## ----- colorscheme -----------------------------------------------------------
    colorschemes.tokyonight = {
      enable = true;
      settings = {
        style = "night";
        styles.functions = {};
        on_colors.__raw = ''
          function(colors)
            colors.bg_statusline = "#36363e"
          end
        '';
        on_highlights.__raw = ''
          function(highlights, colors)
            highlights.WinSeparator = { fg = "#36363e", bg = "#36363e" }
          end
        '';
      };
    };

    ## ----- plugins (declarative) -------------------------------------------------
    plugins = {
      telescope = {
        enable = true;
        settings.defaults.mappings.i = {
          "<C-u>" = { __raw = "false"; };
          "<C-d>" = { __raw = "false"; };
        };
        keymaps = {
          "<leader>ff" = "find_files";
          "<leader>fg" = "live_grep";
          "<leader>fb" = "buffers";
          "<leader>fh" = "help_tags";
          "<leader>fr" = "oldfiles";
          "<leader>fc" = "git_commits";
          "<leader>fs" = "git_status";
          "<leader>fw" = "grep_string";
        };
      };

      cmp = {
        enable = true;
        settings = {
          snippet.expand.__raw = ''
            function(args) vim.fn["vsnip#anonymous"](args.body) end
          '';
          mapping = {
            "<C-p>".__raw   = "cmp.mapping.select_prev_item()";
            "<C-n>".__raw   = "cmp.mapping.select_next_item()";
            "<Up>".__raw    = "cmp.mapping.select_prev_item()";
            "<Down>".__raw  = "cmp.mapping.select_next_item()";
            "<C-S-f>".__raw = "cmp.mapping.scroll_docs(-4)";
            "<C-f>".__raw   = "cmp.mapping.scroll_docs(4)";
            "<C-Space>".__raw = "cmp.mapping.complete()";
            "<C-e>".__raw   = "cmp.mapping.close()";
            "<Tab>".__raw   = "cmp.mapping.confirm({ behavior = cmp.ConfirmBehavior.Insert, select = true })";
          };
          sources = [
            { name = "path"; }
            { name = "nvim_lsp"; keyword_length = 3; }
            { name = "nvim_lsp_signature_help"; }
            { name = "nvim_lua"; keyword_length = 2; }
            { name = "buffer"; keyword_length = 2; }
            { name = "vsnip"; keyword_length = 2; }
            { name = "calc"; }
          ];
          window = {
            completion.__raw   = "cmp.config.window.bordered()";
            documentation.__raw = "cmp.config.window.bordered()";
          };
          formatting = {
            fields = [ "menu" "abbr" "kind" ];
            format.__raw = ''
              function(entry, item)
                local menu_icon = {
                  nvim_lsp = 'λ',
                  vsnip = '⋗',
                  buffer = 'Ω',
                  path = '🖫',
                }
                item.menu = menu_icon[entry.source.name]
                return item
              end
            '';
          };
        };
      };

      trouble.enable  = true;
      fidget.enable   = true;
      lspsaga.enable  = true;
      fugitive.enable = true;
      gitblame.enable = true;

      lsp = {
        enable = true;
        servers = {
          clangd = {
            enable = true;
            cmd = [ "clangd" "--background-index" "--clang-tidy" "--header-insertion=iwyu" ];
          };
          nil_ls.enable  = true;
          lua_ls = {
            enable = true;
            settings.Lua.diagnostics.globals = [ "vim" ];
          };
          pyright.enable  = true;
          bashls.enable   = true;
          yamlls.enable   = true;
          marksman.enable = true;
        };
      };
    };

    ## ----- extra plugins (no dedicated nixvim options) ---------------------------
    extraPlugins = with pkgs.vimPlugins; [
      cmp-buffer
      cmp-nvim-lsp
      cmp-nvim-lsp-signature-help
      cmp-nvim-lua
      cmp-path
      cmp-vsnip
      ctrlp-vim
      haskell-tools-nvim
      kotlin-vim
      lean-nvim
      purescript-vim
      rust-vim
      rustaceanvim
      vim-markdown
      vim-nix
      vim-vsnip
    ];

    ## ----- keymaps ---------------------------------------------------------------
    keymaps = [
      # escape remaps
      { mode = "i"; key = "jk"; action = "<Esc>"; }
      { mode = "i"; key = "kj"; action = "<Esc>"; }
      { mode = "n"; key = ";;"; action = ":w<CR>"; }

      # unicode insert
      { mode = "i"; key = "<M-l>"; action = "λ"; }
      { mode = "i"; key = "<M-a>"; action = "α"; }
      { mode = "i"; key = "<M-b>"; action = "β"; }
      { mode = "i"; key = "<M-v>"; action = "✅"; }
      { mode = "i"; key = "<M-x>"; action = "❌"; }

      # buffer navigation
      { mode = "n"; key = "<Tab>";   action = ":bn<CR>"; }
      { mode = "n"; key = "<S-Tab>"; action = ":bp<CR>"; }
      { mode = "n"; key = "`";       action = ":b#<CR>"; }

      # window navigation
      { mode = "n"; key = "<C-j>"; action = "<C-w>j"; }
      { mode = "n"; key = "<C-k>"; action = "<C-w>k"; }
      { mode = "n"; key = "<C-h>"; action = "<C-w>h"; }
      { mode = "n"; key = "<C-l>"; action = "<C-w>l"; }

      # reselect visual block after indent
      { mode = "v"; key = "<"; action = "<gv"; }
      { mode = "v"; key = ">"; action = ">gv"; }

      # misc
      { mode = "n"; key = "Y"; action = "y$"; }
      { mode = "n"; key = "<leader>l"; action = ":set list!<CR>"; }
      { mode = "n"; key = "<leader>p"; action = ":set paste<CR>:r !pbpaste<Esc>``:set nopaste<CR>"; options.silent = true; }
      { mode = "c"; key = "w!!"; action = "w !sudo tee > /dev/null %"; }

      # diagnostics
      { mode = "n"; key = "<space>e"; action.__raw = "vim.diagnostic.open_float"; options.silent = true; }
      { mode = "n"; key = "[d";       action.__raw = "vim.diagnostic.goto_prev";  options.silent = true; }
      { mode = "n"; key = "]d";       action.__raw = "vim.diagnostic.goto_next";  options.silent = true; }
      { mode = "n"; key = "<space>q"; action.__raw = "vim.diagnostic.setloclist"; options.silent = true; }

      # trouble
      { mode = "n"; key = "<leader>xw"; action = "<cmd>Trouble diagnostics toggle<cr>";              options.silent = true; }
      { mode = "n"; key = "<leader>xd"; action = "<cmd>Trouble diagnostics toggle filter.buf=0<cr>"; options.silent = true; }
      { mode = "n"; key = "<leader>xq"; action = "<cmd>Trouble qflist toggle<cr>";                   options.silent = true; }

      # haskell / ctags
      {
        mode = "n"; key = "<leader>h";
        action = ":!${pkgs.haskellPackages.hasktags}/bin/hasktags -o tags -c . && ${pkgs.universal-ctags}/bin/ctags --options-maybe=.ctags --options=$HOME/.ctags --append=yes .<CR><CR>";
      }
      {
        mode = "n"; key = "<leader>o";
        action = "!${pkgs.haskellPackages.ormolu}/bin/ormolu --mode inplace $(find . -not -path \"./dist-newstyle*\" -not -path \"./.stack-work*\" -name '*.hs')<CR><CR>";
      }
      {
        mode = "n"; key = "<leader>t";
        action = ":!${pkgs.universal-ctags}/bin/ctags --options-maybe=.ctags --options=$HOME/.ctags .<CR><CR>";
      }
    ];

    ## ----- extra lua config ------------------------------------------------------
    extraConfigLua = ''
      -- append-style options that can't be expressed in opts
      vim.opt.shortmess = vim.opt.shortmess + { c = true }
      vim.opt.wildignore:append("*\\tmp\\*")
      vim.opt.wildignore:append("*.swp")
      vim.opt.wildignore:append("*.swo")
      vim.opt.wildignore:append("*.zip")
      vim.opt.wildignore:append(".git")
      vim.opt.wildignore:append(".cabal-sandbox")
      vim.opt.matchpairs:append("<:>")

      -- lean
      require("lean").setup({})

      -- LSP buffer-local keymaps (applied on attach)
      vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(args)
          local bufopts = { noremap = true, silent = true, buffer = args.buf }
          vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, bufopts)
          vim.keymap.set('n', 'gd', vim.lsp.buf.definition, bufopts)
          vim.keymap.set('n', 'K', vim.lsp.buf.hover, bufopts)
          vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, bufopts)
          vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, bufopts)
          vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, bufopts)
          vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, bufopts)
          vim.keymap.set('n', '<space>wl', function()
            print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
          end, bufopts)
          vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, bufopts)
          vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, bufopts)
          vim.keymap.set('n', '<space>ca', vim.lsp.buf.code_action, bufopts)
          vim.keymap.set('n', 'gr', vim.lsp.buf.references, bufopts)
          vim.keymap.set('n', '<space>f', function() vim.lsp.buf.format { async = true } end, bufopts)

          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client.server_capabilities.inlayHintProvider then
            vim.lsp.inlay_hint.enable(true, { bufnr = args.buf })
          end
        end
      })

      -- filetype-specific settings
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "cpp",
        callback = function()
          vim.opt_local.expandtab = true
          vim.opt_local.tabstop = 4
          vim.opt_local.shiftwidth = 4
        end,
      })
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "go",
        callback = function()
          vim.opt_local.expandtab = false
        end,
      })
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "html", "nix" },
        callback = function()
          vim.opt_local.foldmethod = "indent"
        end,
      })
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "python",
        callback = function()
          vim.opt_local.expandtab = true
          vim.opt_local.tabstop = 4
          vim.opt_local.shiftwidth = 4
        end,
      })
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "rs", "rst" },
        callback = function()
          vim.opt_local.expandtab = true
          vim.opt_local.tabstop = 4
          vim.opt_local.shiftwidth = 4
        end,
      })

      -- strip trailing whitespace
      local function strip_trailing_whitespace()
        local save_cursor = vim.api.nvim_win_get_cursor(0)
        local save_search = vim.fn.getreg('/')
        vim.cmd([[%s/\s\+$//e]])
        vim.fn.setreg('/', save_search)
        vim.api.nvim_win_set_cursor(0, save_cursor)
      end
      vim.keymap.set('n', '<leader>w', strip_trailing_whitespace, { silent = true })

      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "haskell", "scala", "yaml", "cpp", "rs" },
        callback = function(args)
          vim.api.nvim_create_autocmd("BufWritePre", {
            buffer = args.buf,
            callback = strip_trailing_whitespace,
          })
        end,
      })

      -- tabularize
      if vim.fn.exists(':Tabularize') ~= 0 then
        vim.keymap.set('v', '<leader>tt', ':Tabularize /::<CR>')
      end
    '';
  };
}
