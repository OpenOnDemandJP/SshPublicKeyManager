# Changelog

## [1.0.0] - 2026-06-22

### Added
- Web-based interface for managing SSH public keys in `~/.ssh/authorized_keys`
- List registered public keys with type, SHA256 fingerprint, and comment
- Add a new public key with format validation via `ssh-keygen -lf`
- Delete a public key identified by its fingerprint
- Duplicate key detection by fingerprint comparison
- Automatic enforcement of `~/.ssh` (700) and `authorized_keys` (600) permissions
- CSRF protection via `Rack::Protection::AuthenticityToken` with a persistent session secret
- Navbar with page-reload link and Open OnDemand dashboard link
- Admin-configurable appearance via `appearance.yml` (navbar, body, and button colors)
