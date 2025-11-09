# Manage my machine

Set up new Debian-based machine.


## About
The script sets up a new machine from scratch.
The script should be ran once, when you want to initialize a new OS installation and every time, when you want to make changes(add or remove config, packages etc) to your OS.
The script does not keep packages up to date it only makes sure a package is installed. The system `upgrade` is a separate matter, that you have to manually handle.


## Structure
The repo is public and contains Ansible files + a script for pre-Ansible system setup and execution of playbook.
The script also requires an external secrets(vault) file, from somewhere else, where secrets are located.
Currently the secrets file is kept in a private repository and ansible will be able to dynamically fetch and load the secrets file during the playbook run.


## Script
1. Installs some dependecies required(e.g ansible, git etc)
2. Clones the repository temporarily to the machine
3. Asks for information(passwords, locations of files etc)
4. Runs the playbook
5. Cleans up the temporary repository


## Usage
Run script using command:

```
bash <(curl -fsSL ${SCRIPT_URL})
```

or

```
bash <(wget -qO- ${SCRIPT_URL})
```

If neither `curl` or `wget` is installed, install one of them using command:

```
sudo apt install ${curl/wget}
```

or when `sudo` is not configured

```
su root; apt install ${curl/wget}
```

Follow the directions provided in the script and you're done!


## Notes
- Secrets file is contained separately from the repository, since the repository is public and the secrets file could be brute-forced.
