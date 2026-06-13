#!/usr/bin/env nu

# Assert that the Nushell installed by the action matches both the version that
# was requested and the version the action reported on its `nushell-version`
# output. Called from .forgejo/workflows/test.yml once per matrix entry.
#
#   nu tests/assert-version.nu <requested> <reported>
#
#   requested  the `nushell-version` input given to the action ('latest' or a
#              pinned version like '0.101.0').
#   reported   the action's `nushell-version` output (the resolved version).
#
# Exits non-zero on the first failed assertion so the workflow step fails.
def main [requested: string, reported: string] {
    let installed = (version | get version)
    print $"requested=($requested) reported=($reported) installed=($installed)"

    # The action's output must match the binary actually on PATH.
    if $installed != $reported {
        print $"(ansi red)FAIL: action output '($reported)' != installed '($installed)'(ansi reset)"
        exit 1
    }

    # A pinned request must install exactly that version. 'latest' resolves to
    # whatever is current, so only the output/installed match is checked above.
    if $requested != "latest" and $installed != $requested {
        print $"(ansi red)FAIL: installed '($installed)' != requested '($requested)'(ansi reset)"
        exit 1
    }

    print $"(ansi green)PASS: Nushell ($installed)(ansi reset)"
}
