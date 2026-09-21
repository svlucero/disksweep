# Security Policy

## Supported versions

Security updates are provided for the latest published release of DiskSweep.

## Reporting a vulnerability

Do not open a public issue for a suspected vulnerability. Instead, use
[GitHub's private vulnerability reporting](https://github.com/svlucero/disksweep/security/advisories/new) and
include:

- The affected version or commit.
- Reproduction steps or a proof of concept.
- The potential impact, especially any filesystem or deletion risk.
- Any suggested mitigation, if known.

You should receive an acknowledgement within seven days. Please allow time to
investigate and prepare a fix before publicly disclosing the issue.

DiskSweep permanently deletes user-selected files. The documented hard-delete
behavior itself is not a vulnerability, but any way to bypass confirmation,
delete outside the displayed selection, or scan outside the documented home
directory boundary should be reported immediately.
