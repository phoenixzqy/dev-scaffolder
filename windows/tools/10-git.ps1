#Requires -Version 5.1
. "$PSScriptRoot\..\lib\common.ps1"
Write-Banner "Git"
Install-WingetPackage -Id "Git.Git" -DisplayName "Git"

# ── Git aliases ──────────────────────────────────────────────────────────
Write-Step "Configuring Git aliases…"

$aliases = @{
    'l'      = 'log --pretty=format:"%C(yellow)%h\ %ad%Cred%d\ %Creset%s%Cblue\ [%cn]" --decorate --date=short'
    'a'      = 'add'
    'ap'     = 'add -p'
    'c'      = 'commit --verbose'
    'ca'     = 'commit -a --verbose'
    'cm'     = 'commit -m'
    'cam'    = 'commit -a -m'
    'm'      = 'commit --amend --verbose'
    'discard'= 'checkout -- .'
    'd'      = 'diff'
    'ds'     = 'diff --stat'
    'dc'     = 'diff --cached'
    's'      = 'status'
    'co'     = 'checkout'
    'cob'    = 'checkout -b'
    'pon'    = 'push -u origin'
    'rbs'    = '!echo "[fetching...]"; git fetch; echo "[pull and rebasing...]"; git pull origin master --rebase'
    'gbr'    = '!git checkout master && git branch -D $(git branch | grep -v "master")'
    'bclear' = '!git branch | grep -v "master" | xargs git branch -D'
    'graph'  = 'log --graph --date-order -C -M --pretty=format:"<%h> %ad [%an] %Cgreen%d%Creset %s" --all --date=short'
    'b'      = "!git for-each-ref --sort='-authordate' --format='%(authordate)%09%(objectname:short)%09%(refname)' refs/heads | sed -e 's-refs/heads/--'"
    'upsub'  = "!f() { cd `$1 && git checkout master && git pull && git submodule update --init --recursive; }; f"
    'subup'  = '!git submodule foreach ''git fetch origin --tags; git checkout master; git pull --rebase'' && git pull && git submodule update --init --recursive'
    'la'     = '!git config -l | grep alias | cut -c 7-'
}

foreach ($key in $aliases.Keys) {
    & git config --global "alias.$key" $aliases[$key]
}

Write-Ok "Git aliases configured"
