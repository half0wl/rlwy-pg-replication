#!/bin/bash
# ########################################################################### #
# https://railway.com
#
# Common utilities for bash scripts.
# ########################################################################### #

# ANSI colors
GREEN_R='\033[0;32m'
GREEN_B='\033[1;92m'
RED_R='\033[0;31m'
RED_B='\033[1;91m'
YELLOW_R='\033[0;33m'
YELLOW_B='\033[1;93m'
PURPLE_R='\033[0;35m'
PURPLE_B='\033[1;95m'
WHITE_R='\033[0;37m'
WHITE_B='\033[1;97m'
NC='\033[0m'

# is_dry_run() checks if the --dry-run flag is present in the arguments.
# Returns true if the flag is present, false otherwise.
#
# Usage:
#
#   DRY_RUN=$(is_dry_run "$@")
#   if [ "$DRY_RUN" = "true" ]; then
#       echo "dryrun"
#   else
#       echo "normal"
#   fi
is_dry_run() {
    local dry_run=false
    for arg in "$@"; do
        case $arg in
            --dry-run)
                dry_run=true
                break
                ;;
        esac
    done
    echo "$dry_run"
}

# confirm() shows a prompt to the user and returns true if the user types
# 'y' or 'Y'. Returns false otherwise.
#
# Usage:
#
#   if confirm "Continue?"; then
#     # yes
#   else
#    # no
#    exit 1
#   fi
confirm() {
   local prompt="$1"
   local default="$2"
   default=${default:-"N"}
   if [ "$default" = "Y" ]; then
       echo ""
       prompt="$prompt [Y/n]: "
       echo ""
   else
       echo ""
       prompt="$prompt [y/N]: "
       echo ""
   fi
   read -r -p "$prompt" response
   if [ -z "$response" ]; then
       response=$default
   fi
   if [[ "$response" =~ ^[Yy]$ ]]; then
       return 0
   else
       return 1
   fi
}

# Logging functions. There is no timestamp for each `log_` function by default.
# To include a timestamp, pass "ts" as the first argument.
#
# Usage:
#
#     log "foo"
#     log "ts" "foobar with timestamp"
#     ...
ts() {
    date +'%d-%m-%Y %H:%M:%S'
}

log() {
    local msg="$1"
    local with_timestamp=false

    if [[ "$1" == "ts" ]]; then
        msg="$2"
        with_timestamp=true
    fi

    if $with_timestamp; then
        echo -e "[$(ts)][ ${WHITE_R}ℹ️ INFO${NC} ] ${WHITE_B}$msg${NC}"
    else
        echo -e "[ ${WHITE_R}ℹ️ INFO${NC} ] ${WHITE_B}$msg${NC}"
    fi
}

log_hl() {
    local msg="$1"
    local with_timestamp=false

    if [[ "$1" == "ts" ]]; then
        msg="$2"
        with_timestamp=true
    fi

    if $with_timestamp; then
        echo -e "[$(ts)][ ${PURPLE_R}ℹ️ INFO${NC} ] ${PURPLE_B}$msg${NC}"
    else
        echo -e "[ ${PURPLE_R}ℹ️ INFO${NC} ] ${PURPLE_B}$msg${NC}"
    fi
}

log_ok() {
    local msg="$1"
    local with_timestamp=false

    if [[ "$1" == "ts" ]]; then
        msg="$2"
        with_timestamp=true
    fi

    if $with_timestamp; then
        echo -e "[$(ts)][ ${GREEN_R}✅ OK${NC}   ] ${GREEN_B}$msg${NC}"
    else
        echo -e "[ ${GREEN_R}✅ OK${NC}   ] ${GREEN_B}$msg${NC}"
    fi
}

log_warn() {
    local msg="$1"
    local with_timestamp=false

    if [[ "$1" == "ts" ]]; then
        msg="$2"
        with_timestamp=true
    fi

    if $with_timestamp; then
        echo -e "[$(ts)][ ${YELLOW_R}⚠️ WARN${NC} ] ${YELLOW_B}$msg${NC}"
    else
        echo -e "[ ${YELLOW_R}⚠️ WARN${NC} ] ${YELLOW_B}$msg${NC}"
    fi
}

log_err() {
    local msg="$1"
    local with_timestamp=false

    if [[ "$1" == "ts" ]]; then
        msg="$2"
        with_timestamp=true
    fi

    if $with_timestamp; then
        echo -e "[$(ts)][ ${RED_R}⛔ ERR${NC}  ] ${RED_B}$msg${NC}" >&2
    else
        echo -e "[ ${RED_R}⛔ ERR${NC}  ] ${RED_B}$msg${NC}" >&2
    fi
}
