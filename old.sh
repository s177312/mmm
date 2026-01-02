#!/bin/bash


readonly DYNAMIC_VARS_FILE='group_vars/local/dynamic.yaml'
readonly DYNAMIC_VARS_FILE_TEMPLATE='template.dynamic.yaml'

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