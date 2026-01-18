# Labby Backlog

## Future Features

### Local Icon Overrides
Allow users to override icons for specific services that don't have good dark/light mode variants on the CDN.

**Context:** Some icons in the dashboard-icons CDN (like Ollama) don't have `-light` variants, making them hard to see on dark backgrounds. A local override system would let users specify custom icon URLs for specific services.

**Potential approach:**
- Add optional `iconURLStringLight` field to Service model
- In Settings or service detail, allow user to set a custom dark mode icon URL
- `IconURLTransformer` checks for local override before falling back to CDN transformation
