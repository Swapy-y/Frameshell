# CachyOS's fish setup (only there; on plain Arch it is skipped)
if test -f /usr/share/cachyos-fish-config/cachyos-config.fish
    source /usr/share/cachyos-fish-config/cachyos-config.fish
end

function fish_greeting
end

# Disable Tab completion
function fish_user_key_bindings
    bind \t accept-autosuggestion
end

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end

# FZF config

# Add fzf to PATH if installed in ~/.fzf
fish_add_path "$HOME/.fzf/bin"

if status is-interactive; and type -q fzf
    # FZF default options and theme
    set -gx FZF_DEFAULT_OPTS "
    --color=fg:#e6e6e6,fg+:#ffffff,bg:-1,bg+:-1
    --color=hl:#5b5b5b:bold:underline,hl+:#c3c3c3:bold:underline
    --color=prompt:#e6e6e6,pointer:#ffffff,marker:#5b5b5b
    --color=info:#636363,spinner:#5b5b5b,header:#5b5b5b
    --color=label:#ffffff,query:#c3c3c3,gutter:-1
    --prompt='❯ '
    --pointer='❯'
    --marker='✓'
    --gutter=' '
    --color=border:#c3c3c3
    --border=rounded
    --no-separator
    --no-scrollbar"

    # Key bindings and completions (Ctrl+T, Ctrl+R, Alt+C)
    fzf --fish | source

    # Ctrl+F file search (fish 4.0+ syntax; use \cf on older fish)
    bind ctrl-f fzf-file-widget
end