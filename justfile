# justfile for the install-nushell composite action.
#
# This repo follows the a8n-run governance conventions (see the `governance`
# repo). Of the three governance justfile templates only `release.just` applies:
# this is a composite action, not a Rust/Docker app, so there is no `cargo`
# toolchain to run hooks against and no Docker footprint to clean up. The
# `cleanup.just` and `hooks.just` templates are therefore intentionally omitted.
#
# The release recipe is adapted from `templates/justfile/release.just`. The
# governance template reads the version from `Cargo.toml` and opens a PR that a
# post-merge create-release workflow later tags and releases. An action has no
# manifest and no build, so the git tag IS the version: the recipe computes the
# next version from the existing tags, pushes an annotated tag, then creates the
# Forgejo Release on that tag directly (via `fj release create`) instead of
# routing through a PR and workflow. The canonical source is on dev.a8n.run
# (Forgejo); the push mirror carries the tag to the GitHub mirror, where
# publishing to the Marketplace remains a manual step.

# List available recipes.
default:
    @just --list

# ── Release ───────────────────────────────────────────────────────────────────

# Tag a release from main and push it to origin so the mirror carries it to GitHub. Usage: just create-release <major|minor|hotfix>
[group: 'release']
create-release bump:
    #!/usr/bin/env nu
    let bump = "{{ bump }}"
    if $bump not-in ["major" "minor" "hotfix"] {
        print $"(ansi red)Usage: just create-release <major|minor|hotfix>(ansi reset)"
        exit 1
    }

    # Abort if the working tree is dirty.
    let status = git status --porcelain | str trim
    if ($status | is-not-empty) {
        print $"(ansi red)Working tree is dirty. Stash or commit your changes first.(ansi reset)"
        exit 1
    }

    # Releases are cut from main. Switch if needed, then pull the latest.
    let branch = git branch --show-current | str trim
    if $branch != "main" {
        print $"Switching from ($branch) to main..."
        git checkout main
    }
    git pull --rebase origin main

    # Current version = highest existing vX.Y.Z tag, or 0.0.0 if none exist yet.
    let tags = git tag | lines | where { |t| $t =~ '^v\d+\.\d+\.\d+$' }
    let versions = $tags | each { |t| $t | str replace --regex '^v' '' | split row '.' | each { into int } }
    let current = if ($versions | is-empty) {
        [0 0 0]
    } else {
        $versions | sort-by { |v| ($v.0 * 1000000) + ($v.1 * 1000) + $v.2 } | last
    }

    let next = match $bump {
        "major" => [($current.0 + 1) 0 0],
        "minor" => [$current.0 ($current.1 + 1) 0],
        "hotfix" => [$current.0 $current.1 ($current.2 + 1)],
    }
    let bare = $next | each { into string } | str join '.'
    let tag = $"v($bare)"

    if $tag in (git tag | lines) {
        print $"(ansi red)Tag ($tag) already exists.(ansi reset)"
        exit 1
    }

    # Annotated tag so the release carries a message; push only the tag.
    git tag --annotate $tag --message $"Release ($tag)"
    git push origin $tag

    # Create the Forgejo Release attached to the tag we just pushed. A pushed
    # tag alone shows up under "tags" but not "releases"; this is what produces
    # the Release entry (with changelog) the other repos get from their
    # post-merge create-release workflow. The changelog spans the previous
    # release tag to HEAD, or all commits on the first release. `--host
    # dev.a8n.run` because more than one host lives in keys.json.
    let prev_bare = $current | each { into string } | str join '.'
    let prev_tag = $"v($prev_bare)"
    let changelog = if ($versions | is-empty) {
        ^git log --pretty="- %s" | str trim
    } else {
        ^git log --pretty="- %s" $"($prev_tag)..HEAD" | str trim
    }
    let body = $"## Changelog\n\n($changelog)"
    let release = ^fj --host dev.a8n.run release create $tag --tag $tag --body $body | complete
    if $release.exit_code != 0 {
        print $"(ansi red)fj release create failed(ansi reset)"
        print $release.stderr
        exit 1
    }

    # Move the floating major tag (vX) to this release so consumers can pin to
    # the major line, e.g. `uses: .../action-install-nushell@v0`. The tag is
    # reused across releases, so --force is required to repoint it and to push
    # the moved ref. No separate Release is created for the floating tag.
    let major_tag = $"v($next.0)"
    git tag --annotate --force $major_tag --message $"Release ($tag)"
    git push --force origin $"refs/tags/($major_tag)"

    print $"(ansi green)Released ($tag) and moved floating ($major_tag) to it.(ansi reset)"
    print "The Forgejo Release was created and the tag mirrors to GitHub."
    print "Marketplace listing is still a manual step: on the GitHub mirror,"
    print "edit the mirrored release and check \"Publish to the GitHub Marketplace\"."
