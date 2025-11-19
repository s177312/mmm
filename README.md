# Manage my machine

Ansible configuration for setting up new Debian machine.


## Usage

1. Clone the repo to your machine.
2. Make script *mmm.sh* executable.
3. Run script *mmm.sh*(pass along argument -h|--help for more information).
3. You are done!


## Notes
- Using *su* method to become in Ansible since on a fresh Debian 13 installation, base user is not in *sudo* group.


## Todo
- Refactor current roles
- Test by doing a new fresh Debian installation
