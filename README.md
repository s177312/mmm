# Manage my machine

Ansible configuration for setting up new Debian machine.


## Usage
1. Clone or download the repository to the machine
2. Run `ansible-playbook --verbose --ask-become-pass --ask-vault-password --extra-vars '@./vars.yaml' --extra-vars '@./vault.yaml' mmm.yaml` while in the repository root directory
3. Done!
