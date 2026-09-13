## Description: <br>
Playwright-based web scraping OpenClaw skill that uses simple and stealth browser scripts for dynamic sites and anti-bot-protected pages. <br>

This skill is ready for commercial/non-commercial use. <br>

## Publisher: <br>
[waisimon](https://clawhub.ai/user/waisimon) <br>

### License/Terms of Use: <br>
MIT <br>


## Use Case: <br>
Developers and agents use this skill to scrape web pages that require JavaScript rendering, with a simple mode for regular dynamic pages and a stealth mode for sites that present anti-bot defenses. <br>

### Deployment Geography for Use: <br>
Global <br>

## Known Risks and Mitigations: <br>
Risk: The skill is built for web scraping with anti-bot and stealth behavior, which may be inappropriate on sites where scraping or bypassing protections is not authorized. <br>
Mitigation: Install and use it only for scraping you are authorized to perform; do not use stealth mode to bypass access controls, Cloudflare challenges, CAPTCHAs, rate limits, or login barriers without explicit permission. <br>
Risk: Screenshots, saved HTML, and JSON output can capture sensitive page content. <br>
Mitigation: Treat captured outputs as sensitive data, store them carefully, and delete them when no longer needed. <br>
Risk: Browser automation dependencies and sandbox settings can affect execution security. <br>
Mitigation: Pin and update Playwright, and keep browser sandboxing enabled where possible. <br>


## Reference(s): <br>
- [ClawHub Skill Page](https://clawhub.ai/waisimon/skills/playwright-scraper-skill) <br>
- [Playwright Official Docs](https://playwright.dev/) <br>
- [puppeteer-extra-plugin-stealth](https://github.com/berstend/puppeteer-extra/tree/master/packages/puppeteer-extra-plugin-stealth) <br>
- [deep-scraper skill](https://clawhub.com/opsun/deep-scraper) <br>


## Skill Output: <br>
**Output Type(s):** [Text, JSON, Shell commands, Files, Guidance] <br>
**Output Format:** [Markdown guidance with shell commands; scraper scripts emit console text, JSON results, screenshots, and optional HTML files.] <br>
**Output Parameters:** [1D] <br>
**Other Properties Related to Output:** [Scripts accept a URL argument and environment variables for wait time, headless mode, screenshot path, HTML saving, and user agent.] <br>

## Skill Version(s): <br>
1.2.0 (source: frontmatter, package.json, changelog, server release metadata) <br>

## Ethical Considerations: <br>
Users should evaluate whether this skill is appropriate for their environment, review any generated or modified files before relying on them, and apply their organization's safety, security, and compliance requirements before deployment. <br>
