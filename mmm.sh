#!/usr/bin/env bash

set -euo pipefail

function getScriptDir() {
    local sourcePath="${BASH_SOURCE[0]}"
    local symlinkDir
    local scriptDir

    while [ -L "${sourcePath}" ]
    do
        symlinkDir="$( cd -P "$( dirname "${sourcePath}" )" >/dev/null 2>&1 && pwd )"
        sourcePath="$( readlink "$sourcePath" )"
        
        if [[ "${sourcePath}" != /* ]]
        then
            sourcePath="${symlinkDir}/${sourcePath}"
        fi
    done

    scriptDir="$( cd -P "$( dirname "${sourcePath}" )" >/dev/null 2>&1 && pwd )"

    echo -n "${scriptDir}"
}

SCRIPT_DIR="$(getScriptDir)"
BECOME_PASSWORD_TITLE='become password'
BECOME_PASSWORD_FILE='.become_password.txt'
VAULT_PASSWORD_TITLE='vault password'
VAULT_PASSWORD_FILE='.vault_password.txt'
CUSTOM_VARS_FILE='group_vars/local/.custom.yaml'
VENV_DIR='.venv'

readSecret_RETURN=
function readSecret() {
    local varName="${1}"
    local secret=''
    local confirmSecret=''

    read -s -p "Enter ${varName}: " 'secret'
    echo
    read -s -p "Repeat ${varName}: " 'confirmSecret'
    echo

    if [[ "${secret}" != "${confirmSecret}" ]]
    then
        echo "${varName} values don't match!"

        readSecret "${varName}"

        return 0
    fi

    readSecret_RETURN="${secret}"
}

function readSecret2File() {
    local varName="${1}"
    local filePath="${2}"
    local updateSecretFile=

    if [[ -f "${filePath}" ]]
    then
        read -r -p "Do you wish to update \"${varName}\" in \"${filePath}\"? [y/N]: " 'updateSecretFile'

        case "${updateSecretFile}" in
            [Yy]|[Yy][Ee][Ss])
                ;;
            *)
                return 0
                ;;
        esac
    fi

    readSecret "${varName}"

    echo -n "${readSecret_RETURN}" > "${filePath}"
}

readVar_RETURN=
function readVar() {
    local varName="${1}"
    local val=''
    local confirmVal=

    read -p "Enter ${varName}: " 'val'

    read -r -p "You entered \"${val}\" for ${varName}. Is it correct? [y/N]: " 'confirmVal'

    case "${confirmVal}" in
        [Yy]|[Yy][Ee][Ss])
            readVar_RETURN="${val}"

            return 0;
            ;;
        *)
            readVar "${varName}"

            return 0
            ;;
    esac
}

function readCustomVars2File() {
    local filePath="${1}"
    local updateCustomVars=
    local fileContents=''

    if [[ -f "${filePath}" ]]
    then
        read -r -p "Do you wish to update variables in \"${filePath}\"? [y/N]: " 'updateCustomVars'

        case "${updateCustomVars}" in
            [Yy]|[Yy][Ee][Ss])
                ;;
            *)
                return 0
                ;;
        esac
    fi

    fileContents+='---'$'\n'

    readVar 'user'

    fileContents+="user: ${readVar_RETURN}"$'\n'

    echo -n "${fileContents}" > "${filePath}"
}

function main() {
    local recreateVenv=
    local goInteractive=

    cd "${SCRIPT_DIR}"

    readSecret2File "${BECOME_PASSWORD_TITLE}" "${BECOME_PASSWORD_FILE}"
    readSecret2File "${VAULT_PASSWORD_TITLE}" "${VAULT_PASSWORD_FILE}"

    readCustomVars2File "${CUSTOM_VARS_FILE}"


    if ! dpkg -s python3 python3-pip python3-venv &>/dev/null 
    then
        echo 'Installing requirements for Ansible virtual environment...'
        su -c "apt update && apt install -y python3 python3-pip python3-venv" root
    fi

    if [[ -d "${VENV_DIR}" ]]
    then
        read -r -p "Do you wish to recreate python virtualenv? [y/N]: " 'recreateVenv'

        case "${recreateVenv}" in
            [Yy]|[Yy][Ee][Ss])
                rm -r "${VENV_DIR}"
                ;;
            *)
                ;;
        esac
    fi

    if [[ ! -d "${VENV_DIR}" ]]
    then
        python3 -m venv .venv
        
        (
            source .venv/bin/activate
            pip install -r requirements.txt
        )
    fi

    read -r -p "Do you wish to open interactive mode for manual ansible execution? If no mmm.yaml is ran once! [y/N]: " 'goInteractive'

    case "${goInteractive}" in
        [Yy]|[Yy][Ee][Ss])
            source .venv/bin/activate

            bash --noprofile --norc
            ;;
        *)
            source .venv/bin/activate
            ansible-playbook mmm.yaml
            ;;
    esac
}

main "${@}"
