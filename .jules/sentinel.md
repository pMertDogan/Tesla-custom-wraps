## 2025-05-14 - Plaintext API Key Input
**Vulnerability:** The API Key input field in the settings dialog was a standard TextField without `obscureText: true`, exposing sensitive credentials in plaintext.
**Learning:** The UI was implemented using default TextField properties, which do not obscure text by default.
**Prevention:** Always use `obscureText: true` for inputs that handle sensitive data like API keys, passwords, or tokens.

## 2025-05-14 - Scoped .gitignore for Flutter
**Vulnerability:** A minimal .gitignore was causing build artifacts to be tracked, creating noise and potential issues in the codebase.
**Learning:** Flutter projects generate numerous artifacts in directories like build/ and .dart_tool/ that must be excluded.
**Prevention:** Use a standard Flutter .gitignore to keep the repository clean.
