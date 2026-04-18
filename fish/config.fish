# ══════════════════════════════════════════════════════════════════
#  ArcOS — Fish shell config
#  ~/.config/fish/config.fish
# ══════════════════════════════════════════════════════════════════

# Disable greeting
set -g fish_greeting

# LS_COLORS via vivid
if type -q vivid
    set -gx LS_COLORS (vivid generate molokai)
end

# ── Aliases ───────────────────────────────────────────────────────
alias ls   'ls --color=auto'
alias ll   'ls -lhF --color=auto'
alias la   'ls -lahF --color=auto'
alias lt   'ls -lahFt --color=auto'
alias ..   'cd ..'
alias ...  'cd ../..'
alias grep 'grep --color=auto'
alias ip   'ip --color=auto'
alias mkdir 'mkdir -p'

# Pacman / yay
alias pup  'yay -Syu'
alias pin  'yay -S'
alias prm  'yay -Rns'
alias pss  'yay -Ss'
alias pqi  'yay -Qi'
alias plo  'yay -Qdt'

# Hyprland helpers
alias hreload 'hyprctl reload'
alias hlog    'journalctl -b -p err --no-pager'

# ── Fastfetch on new terminal ──────────────────────────────────────
if status is-interactive
    and type -q fastfetch
    and not set -q FASTFETCH_RAN
    set -gx FASTFETCH_RAN 1
    fastfetch
end
