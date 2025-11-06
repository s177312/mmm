# Manage my machine
Set up and manage personal Debian-based host.

## Usage
1. Save your vault file somewhere.
2. Run command:
```
bash <(curl -fsSL https://raw.githubusercontent.com/s177312/mmm/refs/heads/main/mmm) ${vault_file_absolute_path}
```

## Notes
- Vault file is held separately, since it contains secrets(even though it is encrypted using ansible vault).
