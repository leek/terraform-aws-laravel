# ~/.profile: executed by sh(1) for login shells and sourced by many shells

# Colorized ls support (if available)
if ls --color=auto / >/dev/null 2>&1; then
    export LS_OPTIONS='--color=auto'
    alias ls='ls $LS_OPTIONS'
    alias ll='ls $LS_OPTIONS -l'
    alias l='ls $LS_OPTIONS -lA'
else
    # Fallback for basic systems
    alias ll='ls -l'
    alias l='ls -lA'
fi

# Safety aliases to avoid mistakes
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Laravel/PHP helpful aliases
alias artisan='php artisan'
alias tinker='php artisan tinker'
alias migrate='php artisan migrate'
alias fresh='php artisan migrate:fresh --seed'

# Add current directory to PATH if not already there
case ":$PATH:" in
    *":."*) ;;
    *) PATH="$PATH:." ;;
esac
