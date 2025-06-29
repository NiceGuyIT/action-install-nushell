# Action to Install Nushell

This is a Forgejo/Gitea/GitHub action to install Nushell into the current environment or container.

## Why not setup-nu or setup_nu?

Why not use [setup-nu][1] or [setup_nu][2] instead of reinventing the wheel?

[setup-nu][1] ([marketplace][3]) uses the [GitHub token][5] for API calls. When used outside GitHub, the token is either
blank or the Forgejo/Gitea token resulting in a 401 authentication failure. `setup-nu` can be used only inside GitHub.

[setup_nu][2] ([marketplace][4]) is a little better in that it compiles a [Rust program][6] to determine the
architecture and download Nushell. Using this outside GitHub results in an error that it couldn't find `Cargo.toml`.
Besides not working, pulling in the Rust toolchain just to download Nushell didn't seem efficient.

[1]: https://github.com/hustcer/setup-nu
[2]: https://github.com/pelasgus/setup_nu
[3]: https://github.com/marketplace/actions/setup-nu
[4]: https://github.com/marketplace/actions/setup_nu
[5]: https://github.com/hustcer/setup-nu/blob/e58310efdaea25b269e19437ab7b3103eda690dc/src/setup.ts#L216
[6]: https://github.com/pelasgus/setup_nu/blob/main/src/main.rs