# Action to Install Nushell

This is a Forgejo/Gitea/GitHub action to install Nushell into the current environment or container. The goal is to
create a lightweight installer that works outside GitHub (i.e. in a self-hosted environment). The code is hosted on
[Codeberg][7] with eventual plans to mirror it on Gitea and GitHub.

Note: This hasn't been tested much so you may run into problems. Pull requests are welcome!

## Why not setup-nu or setup_nu?

Why not use [setup-nu][1] or [setup_nu][2] instead of reinventing the wheel?

[setup-nu][1] ([marketplace][3]) uses the [GitHub token][5] for API calls. When used outside GitHub, the token is either
blank or the Forgejo/Gitea token resulting in a 401 authentication failure. `setup-nu` can be used only inside GitHub.
Additionally, `setup-nu` pulls in a 1.8MB webpack file.

[setup_nu][2] ([marketplace][4]) is a little better in that it compiles a [Rust program][6] to determine the
architecture and download Nushell. Using this outside GitHub results in an error that it couldn't find `Cargo.toml`.
Besides not working, pulling in the Rust toolchain just to download Nushell didn't seem efficient.

## Example usage

Here's a complete example with comments.

```yaml
---
on:
  push:
    branches:
      - '**'

defaults:
  run:
    # Set the default shell to nu
    shell: nu {0}

jobs:
  nushell-action:
    name: Nushell action
    # This label is in the Forgejo Runner.
    runs-on: ubuntu-act-22.04
    steps:
      -
        name: Checkout code
        # Use FQDN for clarity.
        uses: https://code.forgejo.org/actions/checkout@v4

      -
        name: Install Nushell
        id: nushell
        # Nothing has been tagged yet. Use main.
        uses: https://codeberg.org/NiceGuyIT/action-install-nushell@main
        with:
          nushell-version: '0.101.0'
          register-plugins: true

      -
        name: Installed Nushell version
        # This will output the Nushell version emitted from the action.
        env:
          NUSHELL_VERSION: ${{ steps.nushell.outputs.nushell-version }}
        run: $env.NUSHELL_VERSION

      -
        name: Nushell version
        # This will run nu's "version" command.
        run: version
```

## Inputs

- `set-default`: Set Nushell as the default shell? This uses `chsh` to change the shell of the default user (usually
  `root`).
- `nushell-version`: Nushell version to install.
- `register-plugins`: Register plugins after installation?
- `create-config`: Create the default config and env files?

## Outputs

- `nushell-version`: Nushell version that was installed. Should match the input of the same name.

[1]: https://github.com/hustcer/setup-nu
[2]: https://github.com/pelasgus/setup_nu
[3]: https://github.com/marketplace/actions/setup-nu
[4]: https://github.com/marketplace/actions/setup_nu
[5]: https://github.com/hustcer/setup-nu/blob/e58310efdaea25b269e19437ab7b3103eda690dc/src/setup.ts#L216
[6]: https://github.com/pelasgus/setup_nu/blob/main/src/main.rs
[7]: https://codeberg.org/NiceGuyIT/action-install-nushell