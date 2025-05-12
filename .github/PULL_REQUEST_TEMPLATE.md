## Pull Request Overview

### What’s Changed

- **Type**: `[FEAT]`, `[BUG]`, `[FIX]`, `[DOC]`, `[REFACTOR]`, etc.
- **Scope**: Brief module or area impacted (e.g. `Auth`, `UI`, `API`, `Docs`).
- **Summary**: One-sentence description of the change in imperative mood.
  
_Example:_

> `[FEAT] Payment: Add Stripe webhook handler`

---

## Motivation & Context

- **Why** are we making this change
- **Problem** it solves or **feature** it enables
- **User impact** or **business value**.

---

## Implementation Details

- **Files Affected**: key files or components modified.
- **Approach**: short bullets on your solution (e.g., new endpoint, helper function, UI tweak).
- **Edge Cases** considered or decisions made.

---

## Testing

- **Manual Steps**:

    _Example:_

    ```gherkin
    Feature: Add nmap to the pentesting environment
        From the nix/home-manager configuration
        For the system running Kali GNU/Linux Rolling 2025.1
        With nix (Nix) 2.28.0
        Using Home Manager version 25.05-pre

    Background:
        Given the system is configured with Nix and Home Manager
        And the environment is defined in `home.nix`

    Scenario: Ensure nmap is available after configuration
        Given nmap is added to `home.packages`
        When `home-manager switch -f ./home.nix` is executed
        Then the binary `nmap` is available in the system PATH
        And running `nmap --version` returns a valid output
    ```

- **Automated Tests** (if any):

  - Describe new or updated test suite.

---

## Acceptance Criteria

List clear, verifiable conditions for “Done”

- [ ] Behavior A works (e.g., “Webhook responds 200 OK on valid event”)
- [ ] UI shows correct state for edge case
- [ ] Existing tests still pass

---

## Related Issues & PRs

- Closes `#123`
- Relates to `#456`
- Follow-up to PR `#789`

---

## (Optional) Screenshots

<details>
<summary>Click to expand</summary>

[comment]: # (![Before](link-to-before.png))
[comment]: # (![After](link-to-after.png))

</details>

---

## (Optional) Additional Notes

- Migration steps, rollout plan, feature flag
- Any known limitations or future work

