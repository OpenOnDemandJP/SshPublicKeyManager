# SSH Public Key Manager

## Overview

SSH Public Key Manager is an Open OnDemand Passenger app that provides a web-based interface for managing SSH public keys in `${HOME}/.ssh/authorized_keys`. It is designed for HPC cluster users who need to register or remove SSH public keys through Open OnDemand.

### Security Notes

- Public keys are validated with `ssh-keygen -lf` before being added. Invalid input is rejected.
- Duplicate registrations are rejected if the fingerprint matches an existing key.
- Permissions on `~/.ssh` (700) and `authorized_keys` (600) are set automatically as required by SSH.
- CSRF protection is enabled via `Rack::Protection::AuthenticityToken`. The session signing secret is stored in `~/.config/ssh_key_manager/session_secret` (600) and persists across Passenger restarts.

### File Structure

```
.
├── app.rb                  # Sinatra app (routes and logic for listing, adding, and deleting keys)
├── config.ru               # Passenger / Rack entry point
├── manifest.yml            # Open OnDemand app manifest
├── appearance.yml.example  # Sample appearance config (copy to appearance.yml to customize)
├── misc/                   # Files for local testing only (Gemfile, screenshot, etc.)
└── views/
    ├── layout.erb  # Shared layout (loads Bootstrap)
    └── index.erb   # Key list and add-key form
```

## Screenshots

![Screenshot](misc/screen.png)

## Features

- List registered public keys (type / SHA256 fingerprint / comment)
- Manage multiple public keys
- Add a new public key (with format validation and duplicate check)
- Delete a public key (by fingerprint)

## Requirements

### Open OnDemand

- Open OnDemand 3.0 or later
- `ssh-keygen` (used for key validation and fingerprint lookup)

## App Installation

### 1. Clone the repository

```bash
cd /var/www/ood/apps/sys/
git clone https://github.com/OpenOnDemandJP/SshPublicKeyManager.git
```

### 2. Configure for your site

#### Customizing Appearance (Optional)

Copy `appearance.yml.example` to `appearance.yml` and edit the color values.

```bash
cp appearance.yml.example appearance.yml
```

```yaml
navbar_bg:     "#212529"  # navbar background color
navbar_text:   "#ffffff"  # navbar text and link color
body_bg:       "#f8f9fa"  # page background color
primary_color: "#0d6efd"  # card header and Add button background color
primary_text:  "#ffffff"  # card header and Add button text color
```

After editing, restart Open OnDemand to apply changes (click **Restart Web Server** under **Help** in the navigation bar).

### 3. Verify

Visit your OOD dashboard and look for **SSH Public Key** under **Files**.

## Usage

Open the app in your browser. The page shows your registered public keys and a form for adding a new one.

- **Registered Public Keys**: Lists each key's type, SHA256 fingerprint, and comment. Click **Delete** to remove a key (the fingerprint is used to identify which key to remove).
- **Add a Public Key**: Paste a single public key (e.g. the contents of `id_ed25519.pub`) into the text area and click **Add**. The key is validated before being saved, and duplicate keys are rejected.

## Troubleshooting

For bugs or feature requests, [open an issue](https://github.com/OpenOnDemandJP/SshPublicKeyManager/issues) with detailed logs and reproduction steps.

## Testing

### Setup

Clone the repository and install the dependencies.

```bash
git clone https://github.com/OpenOnDemandJP/SshPublicKeyManager.git
cd SshPublicKeyManager
export BUNDLE_GEMFILE=$PWD/misc/Gemfile
bundle install
```

`misc/Gemfile` is only used for local testing (it's not needed to run the app on Open OnDemand, so it's not placed at the top level of the repository). Keep `BUNDLE_GEMFILE` set in the same shell for the commands below.

### Test safely (recommended)

To try the app without touching your real `~/.ssh/authorized_keys`, point `HOME` at a temporary directory when starting it.

```bash
HOME=$(mktemp -d) bundle exec rackup -p 9292
```

Open http://localhost:9292 in your browser.

You can generate a test key like this:

```bash
ssh-keygen -t ed25519 -f /tmp/testkey -N '' -C 'test@local'
cat /tmp/testkey.pub
```

### Run against your real `~/.ssh/authorized_keys`

```bash
bundle exec rackup -p 9292
```

In this case, actions in the UI will modify your real `~/.ssh/authorized_keys`. It's recommended to back it up first.

```bash
cp ~/.ssh/authorized_keys ~/.ssh/authorized_keys.bak
```

## Known Limitations

- The public key storage location is fixed to `${HOME}/.ssh/authorized_keys`.
- Environments where SSH public keys are managed outside of `authorized_keys` (e.g., directly in LDAP) are not supported.

## Contributing

For discussions, see the [GitHub Discussions](https://github.com/OpenOnDemandJP/SshPublicKeyManager/discussions).

## References

- [Open OnDemand](https://openondemand.org/) — the HPC portal framework

## License

[MIT License](LICENSE)
