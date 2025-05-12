# Contributing to Ripper

First off, thank you for considering contributing! We welcome improvements in all areas: new features, bug fixes, documentation, and tooling.

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [How to Report Issues](#how-to-report-issues)
3. [Submitting Changes (Pull Requests)](#submitting-changes-pull-requests)
4. [Branch Naming & Commit Messages](#branch-naming--commit-messages)
5. [Code Style & Testing](#code-style--testing)
6. [Review Process](#review-process)

---

## Getting Started

1. Fork the repository and clone your fork:

   ```bash
   git clone https://github.com/<your-username>/Ripper.git
   cd Ripper
   ```

2. Ensure you have [Nix](https://nixos.org/) installed.
3. Follow the setup instructions in the [README](./README.md).
4. Sync your branch with upstream:

   ```bash
   git remote add upstream https://github.com/PunkerGhoul/Ripper.git
   git fetch upstream
   git checkout main
   git merge upstream/main
   ```

---

## How to Report Issues

Use GitHub Issues to report bugs or request enhancements. A well-formed issue includes:

* **Title**: short, descriptive summary.
* **Description**:

  * Steps to reproduce (for bugs).
  * Expected vs. actual behavior.
  * Nix / Home-Manager versions, OS, error logs.

Please respect issue templates and provide as much context as possible.

---

## Submitting Changes (Pull Requests)

1. Create a feature branch from `main`:

   ```bash
   git checkout -b feat/<scope>-short-description
   ```

2. Make your changes in small, focused commits.
3. Update documentation or examples in `README.md` or Nix files as needed.
4. Run any existing tests or perform manual verification.
5. Push to your fork:

   ```bash
   git push origin feat/<scope>-short-description
   ```

6. Open a Pull Request against the `main` branch of this repo.

---

## Branch Naming & Commit Messages

* **Branch prefix**: `feat/`, `fix/`, `chore/`, `docs/`, `refactor/`.
* **Format**: `<prefix>/<component>-<brief-description>` e.g. `feat/home-manager-modules`, `fix/env-example`

**Commit messages** should be:

* Written in English.
* Use the imperative mood: `Add`, `Fix`, `Remove`.
* Reference the type: `[FEAT]`, `[BUG]`, `[DOC]`, etc.

Example:

```markdown
[FEAT] modules: Add new `ripgrep` helper function
```

---

## Code Style & Testing

* Follow existing Nix and shell conventions in this repo.
* Keep your changes idempotent and reproducible with Home-Manager.
* If you add new modules or scripts, consider how they integrate with `home.nix`.
* Manual verification is required:

  * Reload your Home-Manager config:

    ```bash
    home-manager switch -f ./home.nix
    ```

  * Verify the expected behaviour on your system.

---

## Review Process

* PRs are reviewed by the maintainers.
* Please respond to review comments in a timely manner.
* Once approved, your PR will be merged.

---

Thank you for helping make Ripper better!
