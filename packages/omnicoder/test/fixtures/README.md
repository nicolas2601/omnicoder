# Fixtures

Static fixtures mirroring a minimal `~/.omnicoder` directory. Tests that need
mutation create a fresh tmpdir via `_helpers.makeHome()` rather than writing
into this folder. These files exist primarily as reference/documentation and
may be copied into a tmpdir when a test benefits from realistic seed data.
