# Manage my machine

Ansible configuration for setting up new Debian machine.


## Usage

1. Clone or download the repo to your machine.
2. Make script *mmm.sh* executable.
3. Run script *mmm.sh*(pass along argument -h|--help for more information).
3. You are done!


## Notes

- Using *su* method to become in Ansible since on a fresh Debian 13 installation, base user is not in *sudo* group.
- The roles are built so that, every role could be ran solo and it should still work. This means, that there is some repetition when running tasks and trying to write things so that tasks are skipped when possible should be prioritised.


## Todo
- git role should loop over repos from vars and clone all of those to repos folder, if ssh connection works...


1. 3 ways to run the script:
    - Straight from the web
    - From the repo, from wherever
    - From the repo, in the correct location

- Make script ask if it should copy the repo with all stuff to the correct place handled by ansible
- Also add into script simple interactive spot so it asks for ssh key stuff and you can upload the key to github and stuff

- Fix web-eid role so it works somehow on Debian 13.
- If vault will get more usage, add functionality to script, so that it first asks whether you want write your vault password or copy a file from somewhere, and then go on as it is now, or copy the file to the correct place, same when updating.
