# Manage my machine

Ansible configuration for setting up new Debian machine.


## Usage

1. Clone the repo to your machine.
2. Make script *mmm.sh* executable.
3. Run script *mmm.sh*(pass along argument -h|--help for more information).
3. You are done!


## Notes

- Using *su* method to become in Ansible since on a fresh Debian 13 installation, base user is not in *sudo* group.
- The roles are built so that, every role could be ran solo and it should still work. This means, that there is some repetition when running tasks and trying to write things so that tasks are skipped when possible should be prioritised.


## Todo

- Fix web-eid role so it works somehow on Debian 13.
- If vault will get more usage, add functionality to script, so that it first asks whether you want write your vault password or copy a file from somewhere, and then go on as it is now, or copy the file to the correct place, same when updating.
