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
# create-release workflow later tags. An action has no manifest and no build, so
# the git tag IS the version and the release: the recipe computes the next
# version from the existing tags and pushes an annotated tag directly. The
# canonical source is on dev.a8n.run (Forgejo); the push mirror carries the tag
# to the GitHub mirror, where you draft the Marketplace release from that tag.

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

    print $"(ansi green)Tagged and pushed ($tag).(ansi reset)"
    print "Next: on the GitHub mirror, draft a release from this tag and check"
    print "\"Publish this Action to the GitHub Marketplace\"."
