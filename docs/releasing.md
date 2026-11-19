# Builds and releases

Before each release, add the version's section to `CHANGELOG.md` (newest first). The same section goes into the CurseForge file's changelog and the GitHub release notes.

Every push to `main` and every pull request runs Lua 5.1 syntax checks, the
addon tests, packaging tests and an installable ZIP build. Download test
builds from the **Checks and package** workflow's `AuctionHero-build`
artifact on the Actions page. These builds do not publish a release.

To build a ZIP locally (the source's TOC is not changed):

```sh
python3 scripts/package.py                 # version from the TOC
python3 scripts/package.py --version 0.2.0 # stamped into the ZIP only
```

Versions are plain `major.minor.patch`, such as `0.1.0`, for alpha, beta and
public releases alike. ZIP names (`AuctionHero-0.1.0.zip`), tags (`v0.1.0`)
and the packaged TOC never include alpha, beta or rc suffixes. The `0.x`
series communicates early development. Release status is separate: a
**prerelease** is for testing; a **public release** means ready for general
use. A public release can still be `0.x` and does not mean development is
finished or require a `1.0.0` version.

To publish a prerelease, push a version tag. The **Release** workflow runs
every check, stamps the version into the packaged TOC and publishes a
**GitHub Release** with the ZIP, its SHA-256 checksum and generated notes.
Tag pushes always mark it as a prerelease, outside GitHub's latest release.

```sh
git tag -a v0.1.0 -m 'Auction Hero 0.1.0'
git push origin v0.1.0
```

A release can also be started from **Actions -> Release -> Run workflow** on
`main`. Enter a plain version and leave `public_release` unchecked for an
alpha/beta, or check it to publish directly for general use as the latest
release. A failed check prevents publication, an existing tag is never
recreated, and pushing ordinary commits never publishes anything.

To graduate a tested beta to a public release, edit the existing GitHub
release, clear its prerelease status and mark it as latest. The same version,
tag, ZIP and checksum stay in place; no rebuild or version bump is needed.
With the [GitHub CLI](https://cli.github.com/manual/gh_release_edit):

```sh
gh release edit v0.1.0 --prerelease=false --latest
```

