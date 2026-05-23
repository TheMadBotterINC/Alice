# Security Policy

Alice is used by organizations in regulated industries — aviation MRO, heavy civil, and defense-adjacent operators working under CUI, ITAR, and CMMC. We take security seriously because they have to. If you've found a vulnerability, thank you for helping us keep them safe.

## Reporting a vulnerability

**Please do not report security vulnerabilities through public GitHub issues, discussions, or pull requests.**

Use one of these private channels:

1. **GitHub private vulnerability reporting (preferred):** go to the **Security** tab of this repo → **Report a vulnerability**.
2. **Email:** security@themadbotter.com

Please include:

- A description of the issue and the affected component/version
- Steps to reproduce (a minimal proof of concept helps a lot)
- The impact you believe it has

**Do not include real or customer-derived data, credentials, connection strings, or any CUI/ITAR-controlled material in your report.** Reproduce against synthetic data only. A report that leaks regulated data creates a second incident on top of the first.

## Scope

**In scope** — the contents of this repository: the Alice engine, connectors, the glass-box query/transformation layer, the CLI, and the bundled deployment tooling.

**Out of scope:**

- **Looking Glass**, our commercial managed product. Report those through your commercial support channel, not here.
- **Your own deployment.** Alice runs inside *your* environment and never phones home, which means securing that environment — network, OS, credentials, the database, who can reach the dashboard — is your responsibility. If you're not sure whether something is an Alice bug or a deployment misconfiguration, send it anyway and we'll help you tell the difference.
- **Third-party dependencies.** Please report those upstream — though if we're shipping a vulnerable version, we want to know so we can bump it.

## Our response targets

We're a small team and we'd rather state honest targets than impressive ones we can't hit:

- **Acknowledge** your report within **3 business days**.
- **Initial assessment and severity** within about **10 business days**.
- Ongoing updates through remediation, with disclosure timing coordinated with you.

These are good-faith targets, not a contractual SLA. (Looking Glass customers get the contractual version.)

## Coordinated disclosure

We practice coordinated disclosure. Please give us a reasonable window to ship a fix before going public — we aim to resolve and disclose within **90 days**, sooner when we can. We'll credit you in the advisory and release notes unless you'd rather stay anonymous.

## Safe harbor

Good-faith security research conducted under this policy — staying in scope, not accessing or altering data that isn't yours, not degrading anyone's service — is welcome. We will not pursue or support legal action against researchers acting in good faith under these terms.

## Supported versions

| Version | Security fixes |
| --- | --- |
| Latest `0.x` minor | ✅ |
| Older `0.x` | ⚠️ Please upgrade to the latest |

We'll publish a fuller support matrix at `1.0`.
