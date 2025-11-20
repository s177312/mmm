#!/usr/bin/env bash

set -euo pipefail

# GLOBALS

readonly -a REQUIRED_APT_PACKAGES=(
    'python3'
    'python3-pip'
    'python3-venv'
    'yq'
)

declare -A SCRIPT_ARGS
SCRIPT_ARGS[update]=0
SCRIPT_ARGS[interactive]=0
SCRIPT_ARGS[cleanup_secrets]=0

# All paths are relative to the directory the script is located in
readonly BECOME_PASSWORD_FILE='.become_password.txt'
readonly VAULT_PASSWORD_FILE='.vault_password.txt'
readonly DYNAMIC_VARS_FILE='group_vars/local/dynamic.yaml'
readonly DYNAMIC_VARS_FILE_TEMPLATE='template.dynamic.yaml'
readonly VENV_DIR='.venv'
readonly PLAYBOOK_FILE='mmm.yaml'

# /GLOBALS


# FUNCTIONS

parse_args() {
    while (( $# > 0 )); do
        case "$1" in
            --help)
                print_help
                exit 0
                ;;
            --update)
                SCRIPT_ARGS[update]=1
                shift
                ;;
            --interactive)
                SCRIPT_ARGS[interactive]=1
                shift
                ;;
            --cleanup_secrets)
                SCRIPT_ARGS[cleanup_secrets]=1
                shift
                ;;
            --*)
                print_error "Unknown long option \"$1\" passed to script!"
                exit 1
                ;;
            -h)
                print_help
                exit 0
                ;;
            -u)
                SCRIPT_ARGS[update]=1
                shift
                ;;
            -i)
                SCRIPT_ARGS[interactive]=1
                shift
                ;;
            -c)
                SCRIPT_ARGS[cleanup_secrets]=1
                shift
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
Script for setting up and running mmm ansible configuration.
Usage: $0 [options]

Options:
  -u, --update           Do over the script initialization by picking which things to update and which do not update
  -i, --interactive      Stay in the ansible virtual environment after everything has been set up
  -h, --help             Show this help text

Example:
  $0 --update --interactive
EOF
}

print_error() {
    echo "$1" >&2
}


get_script_dir() {
    local -r ret_val_ref="$1"
    local -n ret_val="${ret_val_ref}"

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

    ret_val="${scriptDir}"
}

install_apt_pkgs() {
    local -r pkgs_name="$1"
    local -nr pkgs="${pkgs_name}"

    local uninstalled_pkgs=()

    for pkg in "${pkgs[@]}"; do
        if ! dpkg -s "${pkg}" &>/dev/null; then
            uninstalled_pkgs+=("${pkg}")
        fi
    done

    if [[ -z "${uninstalled_pkgs:-}" ]]; then
        return 0
    fi

    echo 'One or more required apt packages are not installed:';

    for pkg in "${uninstalled_pkgs[@]}"; do
        echo "  Package ${pkg} not installed!"
    done

    echo "Required apt packages will be installed!";

    if ! continue_script 'yes'; then
        exit 1
    fi

    su -c "apt-get update && apt-get install -y ${uninstalled_pkgs[*]}" 'root'
}



continue_script() {
    local -r default_action="${1:-'no'}"
    local -r question="${2:-'Do you want to continue?'}"
    local confirmation

    read -r -p "${question} [y/N]: " 'confirmation'

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

read_secret() {
    local -r ret_val_ref="$1"
    local -n ret_val="${ret_val_ref}"

    local -r secret_name="$2"
    local secret=''
    local confirm_secret=''

    while :; do
        read -s -p "Enter ${secret_name}: " 'secret'
        echo
        read -s -p "Repeat ${secret_name}: " 'confirm_secret'
        echo

        if [[ "${secret}" == "${confirm_secret}" ]]; then
            break
        fi

        print_error "Values for ${secret_name} don't match! Try again!"
    done

    ret_val="${secret}"
}

read_secret_2_file() {
    local -r secret_name="$1"
    local -r file_path="$2"
    local -r update_secret="$3"

    if [[ -f "${file_path}" ]] && (( update_secret == 0 )); then
        return 0
    fi

    local secret_val=''
    read_secret secret_val "${secret_name}"

    if (( update_secret == 1 )); then
        echo "File ${file_path} has been updated!"
    else
        echo "File ${file_path} has been created!"
    fi

    echo -n "${secret_val}" > "${file_path}"
}

read_var() {
    local -r ret_val_ref="$1"
    local -n ret_val="${ret_val_ref}"

    local -r var_name="$2"
    local var=''
    local confirmVar=

    while :; do
        read -p "Enter ${var_name}: " 'var'

        echo "You entered \"${var}\" for ${var_name}."

        if continue_script 'no'; then
            break
        fi
    done

    ret_val="${var}"
}

read_dynamic_vars_2_file() {
    local -r file_path="$1"
    local -r template_file_path="$2"
    local -r update_vars="$3"

    if [[ -f "${file_path}" ]] && (( update_vars == 0 )); then
        return 0
    fi

    while :; do
        # Use yq to check, that there is no nesting(maps and lists)
        if yq 'values | map(type != "!!map" and type != "!!seq") | all' "${template_file_path}" &>/dev/null; then
            break
        fi

        print_error "Template file contains invalid yaml at ${template_file_path}! Fix yaml errors and continue!"
        
        continue_script 'yes'
    done

    local file_contents=''
    file_contents+='---'$'\n'

    declare -A dynamic_vars

    # Create dynamic vars map for bash from template with default values
    while IFS="=" read -r key value; do
        dynamic_vars["${key:1}"]="${value::-1}"
    done < <(yq '. | to_entries | .[] | "\(.key)=\(.value)"' "${template_file_path}")

    # Create the actual contents for dynamic vars file
    for key in "${!dynamic_vars[@]}"; do
        if continue_script 'no' "Do you want to keep the default value of ${key} as \"${dynamic_vars[${key}]}\"?"; then
            file_contents+="${key}: \"${dynamic_vars[${key}]}\""$'\n'
            continue
        fi

        local user_dynamic_var=''
        read_var user_dynamic_var "${key}"

        file_contents+="${key}: \"${user_dynamic_var}\""$'\n'
    done

    if (( update_vars == 1 )); then
        echo "File ${file_path} has been updated!"
    else
        echo "File ${file_path} has been created!"
    fi

    echo -n "${file_contents}" > "${file_path}"
}

create_virtual_env() {
    local -r dir_path="$1"
    local -r update_venv="$2"

    if [[ -d "${dir_path}" ]] && (( update_venv == 0 )); then
        return 0
    elif [[ -d "${dir_path}" ]]; then
        rm -r "${dir_path}"
    fi

    python3 -m venv "${dir_path}"
        
    (
        source .venv/bin/activate
        pip install -r requirements.txt
    )

    if (( update_venv == 1 )); then
        echo "Virtual environment has been updated!"
    else
        echo "Virtual environment has been created!"
    fi
}

run_ansible() {
    local -r playbook_file_path="$1"
    local -r go_interactive="$2"

    if (( go_interactive == 1 )); then
        echo "Run command \"ansible-playbook ${playbook_file_path}\" to run the main playbook and do other stuff with ansible."
        echo "Press \"Ctrl+d\" to exit the virtual environment terminal session and continue on with the script!"

        (
            source .venv/bin/activate

            bash --noprofile --norc
        )
    else
        echo "Running command \"ansible-playbook ${playbook_file_path}\"!"

        (
            source .venv/bin/activate
            ansible-playbook mmm.yaml
        )
    fi
}

cleanup() {
    local -r cleanup_secrets="$1"

    if (( cleanup_secrets == 1 )); then
        rm "${BECOME_PASSWORD_FILE}"
        rm "${VAULT_PASSWORD_FILE}"
    fi
}

main() {
    parse_args "$@"

    echo 'Running mmm...'

    echo 'Moving to root directory...'
    local script_dir=''
    get_script_dir script_dir
    cd "${script_dir}"

    echo 'Checking required apt packages...'
    install_apt_pkgs REQUIRED_APT_PACKAGES

    echo 'Checking passwords...'
    read_secret_2_file 'become password' "${BECOME_PASSWORD_FILE}" "${SCRIPT_ARGS[update]}"
    read_secret_2_file 'vault password' "${VAULT_PASSWORD_FILE}" "${SCRIPT_ARGS[update]}"

    echo 'Checking dynamic ansible vars...'
    read_dynamic_vars_2_file "${DYNAMIC_VARS_FILE}" "${DYNAMIC_VARS_FILE_TEMPLATE}" "${SCRIPT_ARGS[update]}"

    echo 'Checking virtual environment...'
    create_virtual_env "${VENV_DIR}" "${SCRIPT_ARGS[update]}"

    run_ansible "${PLAYBOOK_FILE}" "${SCRIPT_ARGS[interactive]}"

    echo 'Doing cleanup...'
    cleanup "${SCRIPT_ARGS[cleanup_secrets]}"

    echo 'Script finished...'
}

# /FUNCTIONS


# ENTRY

main "$@"

# /ENTRY
