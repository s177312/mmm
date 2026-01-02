#!/usr/bin/env bash


set -euo pipefail


# GLOBALS
declare -A _ARGS=(
    [COMMAND]='ansible-playbook mmm.yaml'
    [EXTRA]=''
    [UPDATE]=0
    [INTERACTIVE]=0
)

readonly -a _APT_PACKAGES=(
    'python3'
    'python3-pip'
    'python3-venv'
    'yq'
)

readonly BECOME_PASSWORD_FILE='.become_password.txt'
readonly VAULT_PASSWORD_FILE='.vault_password.txt'
readonly VENV_DIR='.venv'
# /GLOBALS


# FUNCTIONS
parse_args() {
    while (( $# > 0 )); do
        case "$1" in
            -c)
                if ! [[ -v 2 ]]; then
                    print_error 'Option value COMMAND for option "-c" is missing!'
                    exit 1
                fi

                _ARGS[COMMAND]="$2"
                shift 2
                ;;
            --command=*)
                _ARGS[COMMAND]="${1##'--command='}"
                shift 1
                ;;
            --command)
                print_error 'Option "--command" needs value COMMAND in the format "--command=COMMAND"!'
                exit 1
                ;;
            -e)
                if ! [[ -v 2 ]]; then
                    print_error 'Option value EXTRA for option "-e" is missing!'
                    exit 1
                fi

                _ARGS[EXTRA]="$2"
                shift 2
                ;;
            --extra=*)
                _ARGS[EXTRA]="${1##'--extra='}"
                shift 1
                ;;
            --extra)
                print_error 'Option "--extra" needs value EXTRA in the format "--extra=EXTRA"!'
                exit 1
                ;;
            -h|--help)
                print_help
                exit 0
                ;;
            -i|--interactive)
                _ARGS[INTERACTIVE]=1
                shift 1
                ;;
            -r|--reset)
                reset_script
                print_line 'Reset finished!'
                exit 0
                ;;
            -u|--update)
                _ARGS[UPDATE]=1
                shift 1
                ;;
            --*)

                print_error "Unknown long option \"$1\" passed to script!"
                exit 1
                ;;
            -*)
                print_error "Unknown short option \"$1\" passed to script!"
                exit 1
                ;;
            *)
                print_error "Unknown argument \"$1\" passed to script!"
                exit 1
                ;;
        esac
    done
}

print_help() {
    cat <<EOF
Usage: $0 [OPTION]...

Manage my machine using Ansible.
The default Ansible command to be ran is "ansible-playbook mmm.yaml".

Options:
  -c COMMAND,        Modify the command to be ran.
  --command=COMMAND
  -e EXTRA,          Append extra arguments, options etc to COMMAND.
  --extra=EXTRA
  -h, --help         Print the help message and die.
  -i, --interactive  Keep the virtual environment open for the user.
  -r, --reset        Reset all changes made by the script to their initial
                     state(does not include changes made by Ansible and 
                     installed packages) and die.
  -u, --update       Rerun the initial script setup asking if any changes 
                     should be made.

Notes:
  This script may be lacking in some ways(ex: since bash parses options, too
  lazy to add combined short option support), so run at your own risk. 8=D
EOF
}

print_error() {
    printf 'mmm: [ERROR] %s\n' "$1" >&2
}

print_line() {
    printf 'mmm: %s\n' "$1"
}

reset_script() {
    if ! continue_script 'no' "Are you sure you wish to reset script?"; then
        return 0
    fi

    rm "${BECOME_PASSWORD_FILE}"
    rm "${VAULT_PASSWORD_FILE}"
    rm -f "${VENV_DIR}"
}

get_script_dir() {
    local -r ret_val_ref="$1"
    local -n _ret_val="${ret_val_ref}"

    local sourcePath="${BASH_SOURCE[0]}"
    local symlinkDir
    local scriptDir

    while [ -L "${sourcePath}" ]; do
        symlinkDir="$( cd -P "$( dirname "${sourcePath}" )" >/dev/null 2>&1 && pwd )"
        sourcePath="$( readlink "$sourcePath" )"
        
        if [[ "${sourcePath}" != /* ]]; then
            sourcePath="${symlinkDir}/${sourcePath}"
        fi
    done

    scriptDir="$( cd -P "$( dirname "${sourcePath}" )" >/dev/null 2>&1 && pwd )"

    _ret_val="${scriptDir}"
}

install_apt_pkgs() {
    local -nr pkgs="$1"

    local uninstalled_pkgs=()

    for pkg in "${pkgs[@]}"; do
        if ! dpkg -s "${pkg}" &>/dev/null; then
            uninstalled_pkgs+=("${pkg}")
        fi
    done

    if [[ -z "${uninstalled_pkgs:-}" ]]; then
        return 0
    fi

    print_line 'One or more required apt packages are not installed!';

    for pkg in "${uninstalled_pkgs[@]}"; do
        print_line "Package ${pkg} not installed!"
    done

    print_line "Required apt packages will be installed!";

    if ! continue_script 'yes'; then
        exit 1
    fi

    su -c "apt-get update && apt-get install -y ${uninstalled_pkgs[*]}" 'root'
}

read_secret() {
    local -r ret_val_ref="$1"
    local -n _ret_val="${ret_val_ref}"

    local -r name="$2"
    local secret=''
    local confirm_secret=''

    while :; do
        read -r -s -p "mmm: Enter ${name}: " 'secret'
        echo
        read -r -s -p "mmm: Repeat ${name}: " 'confirm_secret'
        echo

        if [[ "${secret}" == "${confirm_secret}" ]]; then
            break
        fi

        print_error "Values for ${name} don't match! Try again!"
    done

    _ret_val="${secret}"
}

read_secret_2_file() {
    local -r name="$1"
    local -r path="$2"
    local -r update="$3"

    if [[ -e "${path}" ]]; then
        if (( update == 0 )); then
            return 0
        fi

        if ! continue_script 'yes' "Do you wish to update ${name}?"; then
            return 0
        fi
    fi

    local secret_val=''
    read_secret 'secret_val' "${name}"

    echo -n "${secret_val}" > "${path}"

    print_line "${name} has been updated!"
}

continue_script() {
    local -r default_action="${1:-'no'}"
    local -r question="${2:-"Do you want to continue?"}"
    local confirmation

    read -r -p "mmm: ${question} [y/N]: " 'confirmation'

    case "${confirmation}" in
        [Yy]|[Yy][Ee][Ss])
            return 0;
            ;;
        [Nn]|[Nn][Oo])
            return 1;
            ;;
        *)
            if [[ "${default_action}" == 'yes' ]]; then
                return 0
            fi

            return 1;
            ;;
    esac
}

create_venv() {
    local -r path="$1"
    local -r update="$2"

    if [[ -e "${path}" ]]; then
        if (( update == 0 )); then
            return 0
        fi

        if ! continue_script 'yes' 'Do you wish to update virtual environment?'; then
            return 0
        fi

        rm -r "${path}"
    fi

    python3 -m venv "${path}"
        
    (
        # shellcheck source=/dev/null
        source .venv/bin/activate
        pip install -r requirements.txt
    )
}

start_interactive_venv() {
    print_line 'Press "Ctrl+d" to exit the virtual environment and return to script.'

    (
        # shellcheck source=/dev/null
        source .venv/bin/activate
        bash --noprofile --norc
    )
}

run_venv_command() {
    local -r cmd="$1"

    print_line "Running command \"${cmd}\"."

    (
        # shellcheck source=/dev/null
        source .venv/bin/activate
        ${cmd}
    )
}

main() {
    parse_args "$@"

    print_line 'Initializing...'

    local initial_dir="$PWD"
    local script_dir=''
    get_script_dir script_dir
    
    if [[ "$initial_dir" != "$script_dir" ]]; then
        print_line 'Moving to mmm root directory...'
        cd "${script_dir}"
    fi

    install_apt_pkgs '_APT_PACKAGES'

    read_secret_2_file 'become password' "${BECOME_PASSWORD_FILE}" "${_ARGS[UPDATE]}"
    read_secret_2_file 'vault password' "${VAULT_PASSWORD_FILE}" "${_ARGS[UPDATE]}"

    create_venv "${VENV_DIR}" "${_ARGS[UPDATE]}"

    if (( _ARGS[INTERACTIVE] == 1 )); then
        start_interactive_venv
    else
        run_venv_command "${_ARGS[COMMAND]} ${_ARGS[EXTRA]}"
    fi

    print_line 'Finishing...'

    exit 0
}
# /FUNCTIONS

# ENTRY
main "$@"
# /ENTRY
