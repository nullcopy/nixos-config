## Oh-my-zsh git aliases
## https://github.com/ohmyzsh/ohmyzsh/blob/master/plugins/git/git.plugin.zsh
##
## Sections are grouped by git subcommand so new aliases are easy to slot in.

{ config, lib, ... }:

let
  mainBranch = "$(git_main_branch)";
  devBranch = "$(git_develop_branch)";
  curBranch = "$(git_current_branch)";
in
{
  programs.zsh.initContent = ''
    ## --- git helper functions ----------------------------------------
    # Browse and cd to git worktree directory
    cdwt () {
      local selected
      selected=$(git worktree list | fzf)
      [ -n "$selected" ] && cd "$(echo "$selected" | awk '{print $1}')"
    }

    # Returns the name of the main branch (main or master).
    function git_main_branch() {
      command git rev-parse --git-dir &>/dev/null || return
      local ref
      for ref in refs/{heads,remotes/{origin,upstream}}/{main,trunk,mainline,default,stable,master}; do
        if command git show-ref -q --verify "$ref"; then
          echo "''${ref:t}"
          return 0
        fi
      done
      echo master
      return 1
    }

    # Returns the name of the develop branch (develop, dev, or devel).
    function git_develop_branch() {
      command git rev-parse --git-dir &>/dev/null || return
      local branch
      for branch in dev devel develop development; do
        if command git show-ref -q --verify "refs/heads/$branch"; then
          echo "$branch"
          return 0
        fi
      done
      echo develop
      return 1
    }

    # Returns the name of the current branch.
    function git_current_branch() {
      local ref
      ref="$(command git symbolic-ref --quiet HEAD 2>/dev/null)"
      local ret=$?
      if [[ $ret != 0 ]]; then
        [[ $ret == 128 ]] && return  # no git repo
        ref=$(command git rev-parse --short HEAD 2>/dev/null) || return
      fi
      echo "''${ref#refs/heads/}"
    }
  '';

  programs.zsh.shellAliases = {
    ## --- misc -------------------------------------------------------------------
    ll = "ls -l";
    la = "ls -al";

    ## --- git -------------------------------------------------------------------
    g = "git";

    ga = "git add";
    gaa = "git add --all";
    gapa = "git add --patch";
    gau = "git add --update";
    gav = "git add --verbose";

    gam = "git am";
    gama = "git am --abort";
    gamc = "git am --continue";
    gamscp = "git am --show-current-patch";
    gams = "git am --skip";

    gap = "git apply";
    gapt = "git apply --3way";

    gbs = "git bisect";
    gbsb = "git bisect bad";
    gbsg = "git bisect good";
    gbsn = "git bisect new";
    gbso = "git bisect old";
    gbsr = "git bisect reset";
    gbss = "git bisect start";

    gbl = "git blame -w";

    gb = "git branch";
    gba = "git branch --all";
    gbd = "git branch --delete";
    gbD = "git branch --delete --force";
    gbm = "git branch --move";
    gbnm = "git branch --no-merged";
    gbr = "git branch --remote";
    ggsup = "git branch --set-upstream-to=origin/${curBranch}";
    gbg = ''LANG=C git branch -vv | grep ": gone]"'';
    gbgd = ''LANG=C git branch --no-color -vv | grep ": gone]" | cut -c 3- | awk '{print $1}' | xargs git branch -d'';
    gbgD = ''LANG=C git branch --no-color -vv | grep ": gone]" | cut -c 3- | awk '{print $1}' | xargs git branch -D'';

    gco = "git checkout";
    gcor = "git checkout --recurse-submodules";
    gcb = "git checkout -b";
    gcB = "git checkout -B";
    gcd = "git checkout ${devBranch}";
    gcm = "git checkout ${mainBranch}";

    gcp = "git cherry-pick";
    gcpa = "git cherry-pick --abort";
    gcpc = "git cherry-pick --continue";

    gclean = "git clean --interactive -d";

    gcl = "git clone --recurse-submodules";
    gclf = "git clone --recursive --shallow-submodules --filter=blob:none --also-filter-submodules";

    gc = "git commit --verbose";
    "gc!" = "git commit --verbose --amend";
    gca = "git commit --verbose --all";
    "gca!" = "git commit --verbose --all --amend";
    gcam = "git commit --all --message";
    "gcan!" = "git commit --verbose --all --no-edit --amend";
    "gcans!" = "git commit --verbose --all --signoff --no-edit --amend";
    "gcann!" = "git commit --verbose --all --date=now --no-edit --amend";
    gcas = "git commit --all --signoff";
    gcasm = "git commit --all --signoff --message";
    gcf = "git config --list";
    gcfu = "git commit --fixup";
    gcmsg = "git commit --message";
    gcn = "git commit --verbose --no-edit";
    "gcn!" = "git commit --verbose --no-edit --amend";
    gcs = "git commit --gpg-sign";
    gcsm = "git commit --signoff --message";
    gcss = "git commit --gpg-sign --signoff";
    gcssm = "git commit --gpg-sign --signoff --message";

    gdct = "git describe --tags $(git rev-list --tags --max-count=1)";

    gd = "git diff";
    gdca = "git diff --cached";
    gdcw = "git diff --cached --word-diff";
    gds = "git diff --staged";
    gdt = "git diff-tree --no-commit-id --name-only -r";
    gdup = "git diff @{upstream}";
    gdw = "git diff --word-diff";

    gf = "git fetch";
    gfa = "git fetch --all --tags --prune --jobs=10";
    gfo = "git fetch origin";

    gg = "git gui citool";
    gga = "git gui citool --amend";
    ghh = "git help";

    glg = "git log --stat";
    glgp = "git log --stat --patch";
    glgg = "git log --graph";
    glgga = "git log --graph --decorate --all";
    glgm = "git log --graph --max-count=10";
    glo = "git log --oneline --decorate";
    glog = "git log --oneline --decorate --graph";
    gloga = "git log --oneline --decorate --graph --all";
    glol = ''git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset"'';
    glols = ''git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset" --stat'';
    glola = ''git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset" --all'';
    glod = ''git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset"'';
    glods = ''git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset" --date=short'';

    gfg = "git ls-files | grep";
    gignored = ''git ls-files -v | grep "^[[:lower:]]"'';

    gm = "git merge";
    gma = "git merge --abort";
    gmc = "git merge --continue";
    gmff = "git merge --ff-only";
    gms = "git merge --squash";
    gmom = "git merge origin/${mainBranch}";
    gmum = "git merge upstream/${mainBranch}";
    gmtl = "git mergetool --no-prompt";
    gmtlvim = "git mergetool --no-prompt --tool=vimdiff";

    gl = "git pull";
    gluc = "git pull upstream ${curBranch}";
    glum = "git pull upstream ${mainBranch}";
    ggpull = ''git pull origin "$(git_current_branch)"'';
    gpr = "git pull --rebase";
    gpra = "git pull --rebase --autostash";
    gprav = "git pull --rebase --autostash -v";
    gprom = "git pull --rebase origin ${mainBranch}";
    gpromi = "git pull --rebase=interactive origin ${mainBranch}";
    gprum = "git pull --rebase upstream ${mainBranch}";
    gprumi = "git pull --rebase=interactive upstream ${mainBranch}";
    gprv = "git pull --rebase -v";

    gp = "git push";
    gpd = "git push --dry-run";
    gpf = "git push --force-with-lease --force-if-includes";
    "gpf!" = "git push --force";
    gpoat = "git push origin --all && git push origin --tags";
    gpod = "git push origin --delete";
    gpsup = "git push --set-upstream origin ${curBranch}";
    gpsupf = "git push --set-upstream origin ${curBranch} --force-with-lease --force-if-includes";
    gpv = "git push --verbose";
    ggpush = ''git push origin "$(git_current_branch)"'';
    gpu = "git push upstream";

    grb = "git rebase";
    grba = "git rebase --abort";
    grbc = "git rebase --continue";
    grbd = "git rebase ${devBranch}";
    grbi = "git rebase --interactive";
    grbm = "git rebase ${mainBranch}";
    grbo = "git rebase --onto";
    grbom = "git rebase origin/${mainBranch}";
    grbs = "git rebase --skip";
    grbum = "git rebase upstream/${mainBranch}";

    grf = "git reflog";

    gr = "git remote";
    gra = "git remote add";
    grmv = "git remote rename";
    grrm = "git remote remove";
    grset = "git remote set-url";
    grup = "git remote update";
    grv = "git remote --verbose";

    grh = "git reset";
    grhh = "git reset --hard";
    grhk = "git reset --keep";
    grhs = "git reset --soft";
    groh = "git reset origin/${curBranch} --hard";
    gru = "git reset --";
    gpristine = "git reset --hard && git clean --force -dfx";
    gwipe = "git reset --hard && git clean --force -df";

    grs = "git restore";
    grss = "git restore --source";
    grst = "git restore --staged";

    grev = "git revert";
    greva = "git revert --abort";
    grevc = "git revert --continue";

    grm = "git rm";
    grmc = "git rm --cached";

    gcount = "git shortlog --summary --numbered";
    gsh = "git show";
    gsps = "git show --pretty=short --show-signature";

    gsta = "git stash push";
    gstaa = "git stash apply";
    gstall = "git stash --all";
    gstc = "git stash clear";
    gstd = "git stash drop";
    gstl = "git stash list";
    gstp = "git stash pop";
    gsts = "git stash show --patch";
    gstu = "git stash push --include-untracked";

    gst = "git status";
    gss = "git status --short";
    gsb = "git status --short --branch";

    gsi = "git submodule init";
    gsu = "git submodule update";

    gsd = "git svn dcommit";
    gsr = "git svn rebase";
    git-svn-dcommit-push = "git svn dcommit && git push github ${mainBranch}:svntrunk";

    gsw = "git switch";
    gswc = "git switch --create";
    gswd = "git switch ${devBranch}";
    gswm = "git switch ${mainBranch}";

    gta = "git tag --annotate";
    gts = "git tag --sign";
    gtv = "git tag | sort -V";

    gignore = "git update-index --assume-unchanged";
    gunignore = "git update-index --no-assume-unchanged";

    gwt = "git worktree";
    gwta = "git worktree add";
    gwtls = "git worktree list";
    gwtmv = "git worktree move";
    gwtrm = "git worktree remove";

    grt = ''cd "$(git rev-parse --show-toplevel || echo .)"'';
    gwch = "git log --patch --abbrev-commit --pretty=medium --raw";
  };
}
