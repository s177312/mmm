# Manage my machine

Ansible configuration for setting up new Debian machine.


## Usage

Run script from url: `bash <(curl -s "https://raw.githubusercontent.com/s177312/mmm/refs/heads/main/mmm.sh") --web`

or

Run from the repo:
1. Clone or download the repo to your machine.
2. Make script *mmm.sh* executable.
3. Run script *mmm.sh*(pass along argument -h|--help for more information).
3. You are done!


## Notes

- System upgrading is not done through automation, will stay manual.
- Using *su* method to become in Ansible since on a fresh Debian 13 installation, base user is not in *sudo* group.
- The roles are built so that, every role could be ran solo and it should still work. This means, that there is some repetition when running tasks and trying to write things so that tasks are skipped when possible should be prioritised.


## TODO

- Try to automatically get web-eid working as a role
