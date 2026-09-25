# AI log

How I worked with Claude to design and build Sunset app. Each day: where AI sped me up, where it went wrong, and which calls I made myself.

Brief: https://claude.ai/code/artifact/c843d13f-1a23-4f98-b1e2-1763cfb04736

---

## Day 1 — Sep 25, 2026

_Claude drafted this entry from our session. Edit it into your own words._

**Sped me up**
- Went from five loose ideas to a chosen project and a one-page brief in one sitting.
- Claude set up Git, the `.gitignore`, the public GitHub repo and the deployment target from the terminal, so I didn't have to learn those steps first.

**Went wrong**
- Claude assumed my phone was an iPhone 7 because of its name in Xcode, and set the app to iOS 15. That would have ruled out features I want, like mesh gradients for the sky. When I corrected it, Claude checked the actual device and switched to iOS 18.
- Earlier, Claude read "touch pad" as the trackpad and called the to-do idea impossible, before I pointed out the Touch Bar.

**My calls**
- Dropped Claude's number score for the sunset. It went from a score, to raw data only, to a gentle one-line verdict with no pressure.
- Progressive disclosure: headline first, cloud-height details below or behind a dropdown.
- Screen layout and focus get designed by me in Figma, not generated.
- Edge cases: pin or area picker when location is denied, a cheeky offline screen, a skippable compass calibration.

**Steering Claude**
- Commented directly in the brief to cut or change sections instead of rewriting them myself.
