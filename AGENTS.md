# Repository Guidelines

## Repository Status

This directory is currently an empty project workspace. No application code, package manifest, tests, CI configuration, or Git history is present. Update this guide as the project is initialized; do not treat unconfigured commands or conventions as established requirements.

## Project Structure & Module Organization

Keep application code, tests, and runtime resources in clearly separated directories. If this project adopts Swift Package Manager and Vapor, use `Sources/<Target>/` for application modules and `Tests/<Target>Tests/` for corresponding tests. Add `Public/` or `Resources/` only when static assets or templates are needed. Document actual targets and entry points once they exist.

## Build, Test, and Development Commands

There are currently no verified build, test, or development commands. After adding a Swift package manifest, verify and document these candidate commands:

- `swift build`: compile package targets.
- `swift test`: run the package test suite.
- `swift run <ExecutableTarget>`: launch the configured executable.

Record required toolchain versions, services, and environment variables alongside setup instructions in `README.md`.

## Coding Style & Naming Conventions

Follow the formatter and language conventions selected during initialization. For Swift, prefer four-space indentation, `UpperCamelCase` type names, and `lowerCamelCase` functions and properties. Name files after their primary type. No formatter or linter is configured yet; commit its configuration when introducing one.

## Testing Guidelines

No test framework or coverage threshold is established. Add tests for new behavior and regression tests for bug fixes. Use descriptive names that identify the scenario and expected outcome. Document any database or service dependencies needed to run tests.

## Commit & Pull Request Guidelines

No Git history is available to establish commit conventions. Use concise, imperative commit subjects, such as `Add application bootstrap`. Keep changes focused. Pull requests should describe the change, link relevant issues, and report validation performed or explain why it was unavailable.

## Security & Configuration

Keep secrets and local credentials out of version control. Provide placeholder values in an example environment file when configuration is introduced.
