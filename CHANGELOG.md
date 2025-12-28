## [1.0.0] - 2026-01-15

### Added

- Initial release of Checkend Elixir SDK
- Error notification with async/sync sending
- Plug middleware integration for Phoenix/Plug apps
- Oban integration for background job error tracking
- Exponential backoff with throttling (1.05^n, max 100s)
- Sensitive data filtering with configurable filter keys
- Exception ignoring (module, string, regex patterns)
- Default Phoenix/Ecto exception ignoring
- HTTP proxy support
- SSL/TLS configuration (ssl_verify, ssl_ca_path)
- App metadata (app_name, revision, root_path)
- Data sending toggles (request, session, environment, user)
- Custom logger support
- Configurable timeouts (connect_timeout, timeout, shutdown_timeout)
- Testing utilities for capturing notices in tests
- before_notify callbacks for notice modification
