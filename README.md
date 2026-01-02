# Manage my machine

Ansible configuration for setting up new Debian machine.


## Usage

1. Clone or download the repo to your machine.
2. Make script *mmm.sh* executable.
3. Run script *mmm.sh*(pass along argument -h|--help for more information).
3. You are done!


## Notes

- System upgrading is not done through automation, will stay manual.
- Using *su* method to become in Ansible since on a fresh Debian 13 installation, base user is not in *sudo* group.
- The roles are built so that, every role could be ran solo and it should still work. This means, that there is some repetition when running tasks and trying to write things so that tasks are skipped when possible should be prioritised.


## TODO
- Refactor the script, Fk the whole dynamic args thingy and interactive stuff, if you run the script it will do everything automatically.
- You can pass --interactive or -i to the script, so you will stay inside the virtualenv to run ansible manually.õ
- That's it.
- Everything that the script creates or installs, will be under a separate ansible role aswell, so it is kind of managed.
- Web Bash running should still work.
- Dynamic template logic for vars, we should not care about it so remove it completely.
    Ex: We can get the user that runs the script automatically.
- The script should also check if root is running it, and not allow root as the one who will run the script.
- Git role will create a repos directory, it will not clone all of my repos automatically. It just creates the dir where i keep repos of all kind.

## Todo
- Figure out the web bash command stuff and so on. Honestly the script itself is starting to look like a fine piece now.
    It almost looks like a cmd tool. So if i generalize it a little bit more, and add somekind of configuration to it as a wrapper to ansible or something like that, it should work pretty well. Figure this shit out. I should have a few ideas floating around...

- In git role:
    - All repos will be located in repos_dir
    - mmm repo will be present in repos_dir root
    - Other repos should be able to define their own parent directory inside repos_dir

- Script setup should create some kind of .configuration file aswell, which actually shows whether the script has been configured or not, a lot simpler to actually handle changes and so on.

- The script should know, when it is ran for the first time.
    - Ran for the first time:
        - Check if repo is setup correctly, ask for correct setup and continue.
    - First time run done:
        - Check if in repo:
            - If in repo just continue
            - If not in repo, treat as if first time run and continue from there

- SSH key handling in script

- Other stuff make mobile hotspot invisible, and connect router to the invisible hotspot

- Web-eid doesn't officially support Debian. On Debian 13, it can't get all of the required packages from the official Debian repos. Make it work somehow, maybe use Ubuntu repos for specific packages?
- Under init role, add dynamic loading of a dynamic vault file. This file is not kept in a repo, but kept in a separate place. This file is loaded only if it exists. Script should ask, where the file is located and then move/copy the file to the correct place.
- Script currently saves vault and become password into a file. Implement it so it is possible to interactively/with arguments specify, whether or not you want to create those files and/or pass your passwords when executing ansible.
