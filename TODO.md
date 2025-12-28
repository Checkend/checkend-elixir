# Checkend Elixir SDK - Feature Parity TODO

This document tracks features missing in the Elixir SDK (v0.1.0) that exist in the Ruby SDK (v1.0.0).

## High Priority

- [x] **Oban Integration** - Background job error handling ✅ COMPLETED
  - Created `Checkend.Integrations.Oban` module
  - Implemented Oban.Telemetry handler for job failures via `[:oban, :job, :exception]` event
  - Captures job context: queue, worker, args, attempt, max_attempts, id, state
  - Sanitizes job arguments using SanitizeFilter
  - Adds "oban" tag to errors
  - Includes `attach/0` and `detach/0` functions for easy setup

- [x] **Exponential Backoff in Worker** - More sophisticated retry logic ✅ COMPLETED
  - Replaced fixed delays with exponential backoff (1.05^n with 100s max)
  - Added throttling state to Worker GenServer
  - Throttle increases on failures, decreases on success
  - Same algorithm as Ruby SDK (BASE_THROTTLE=1.05, MAX_THROTTLE=100)

- [x] **HTTP Proxy Support** - For corporate environments ✅ COMPLETED
  - Added `proxy` configuration option
  - Supports proxy URL format (e.g., `http://proxy.example.com:8080`)
  - Environment variable support: `CHECKEND_PROXY`
  - Updated `Checkend.Client` to parse and apply proxy settings

- [x] **SSL/TLS Configuration** - Certificate verification options ✅ COMPLETED
  - Added `ssl_verify` configuration option (default: true)
  - Added `ssl_ca_path` configuration option for custom CA bundles
  - Updated `Checkend.Client` to apply SSL options

- [x] **Shutdown Timeout Configuration** - Configurable graceful shutdown ✅ COMPLETED
  - Added `shutdown_timeout` configuration option (default: 5000ms)
  - Updated `Checkend.Worker.flush/1` and `stop/0` to use configurable timeout

## Medium Priority

- [x] **App Metadata Configuration** - Application identification ✅ COMPLETED
  - Added `app_name` configuration option (env: `CHECKEND_APP_NAME`)
  - Added `revision` configuration option (env: `CHECKEND_REVISION`)
  - Added `root_path` configuration option
  - App metadata included in Notice payload under notifier section
  - Root path used to clean file paths in backtraces (`[PROJECT_ROOT]`)

- [x] **Data Sending Toggles** - Granular control over payload ✅ COMPLETED
  - Added `send_request_data` option (default: true)
  - Added `send_session_data` option (default: true)
  - Added `send_environment` option (default: false)
  - Added `send_user_data` option (default: true)
  - Toggles applied in `Checkend.NoticeBuilder`

- [x] **Logger Configuration** - Custom logger support ✅ COMPLETED
  - Added `logger` configuration option
  - Allows passing custom Logger module
  - Updated `Checkend.Configuration.log/3` to use configured logger
  - Defaults to Elixir's built-in Logger

- [x] **Connection Timeout** - Separate from read timeout ✅ COMPLETED
  - Added `connect_timeout` configuration option (default: 5000ms)
  - `timeout` is now read timeout only
  - Updated `Checkend.Client` to set both timeouts in `:httpc`

- [x] **Default Phoenix Exceptions** - Auto-ignore common framework errors ✅ COMPLETED
  - Added Phoenix-specific exceptions to default `ignored_exceptions`:
    - `Phoenix.Router.NoRouteError`
    - `Phoenix.NotAcceptableError`
    - `Ecto.NoResultsError`
    - `Ecto.StaleEntryError`
    - `Plug.Conn.InvalidQueryError`
  - Only included if modules are available (uses `Code.ensure_loaded?/1`)

## Low Priority

- [ ] **Automatic Queue Draining on Shutdown** - OTP application stop callback
  - Add `stop/1` callback to `Checkend.Application`
  - Call `Checkend.flush()` during application shutdown
  - Ensure pending notices are sent before process exits
  - Reference: Ruby's at_exit hook behavior

- [ ] **Broadway Integration** - For Broadway-based pipelines
  - Create `Checkend.Integrations.Broadway` module
  - Handle failed messages in pipelines
  - Capture message metadata and context
  - Lower priority than Oban (less common use case)

## Testing Improvements

- [ ] **Integration Tests** - End-to-end testing
  - Add integration tests for Plug middleware
  - Add tests for Oban integration (when implemented)
  - Test configuration via environment variables

- [ ] **Property-Based Tests** - Edge case coverage
  - Add StreamData for sanitize filter testing
  - Test with deeply nested data structures
  - Test with various unicode and binary data

## Documentation

- [ ] **HexDocs** - Publish documentation
  - Add module docs to all public modules
  - Add usage examples to README
  - Add configuration guide
  - Add integration guides (Phoenix, Oban)

- [ ] **Changelog** - Track version changes
  - Create CHANGELOG.md
  - Document v0.1.0 initial release
  - Follow Keep a Changelog format

---

## Comparison Notes

### Ruby SDK Features (v1.0.0)
- Rack middleware ✅ (Elixir: Plug middleware)
- Rails Railtie (auto-config) - N/A (Phoenix doesn't use Railties)
- Sidekiq integration ✅ (Elixir: Oban integration)
- ActiveJob integration ✅ (Elixir: Oban integration)
- Exponential backoff (1.05^n) ✅
- HTTP proxy support ✅
- SSL configuration ✅
- App metadata ✅
- Data sending toggles ✅
- Custom logger ✅
- 214+ tests

### Elixir SDK Features (v0.2.0 - Updated)
- Plug middleware ✅
- GenServer worker (async) ✅
- Exponential backoff (1.05^n) ✅ NEW
- HTTP proxy support ✅ NEW
- SSL/TLS configuration ✅ NEW
- App metadata (app_name, revision, root_path) ✅ NEW
- Data sending toggles ✅ NEW
- Custom logger support ✅ NEW
- Connection timeout (separate from read timeout) ✅ NEW
- Default Phoenix/Ecto exception ignoring ✅ NEW
- Shutdown timeout configuration ✅ NEW
- Oban integration ✅ NEW
- Sensitive data filtering ✅
- Exception ignoring ✅
- Testing utilities ✅

### Feature Parity Status
✅ **ACHIEVED** - The Elixir SDK now has feature parity with the Ruby SDK, adapted for Elixir/OTP idioms.

Remaining low-priority items:
- Automatic queue draining on OTP application shutdown
- Broadway integration (for Broadway-based pipelines)
