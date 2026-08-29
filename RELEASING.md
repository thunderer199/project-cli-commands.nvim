# Releasing

Neovim plugins have no manifest file — the git tag *is* the version. Plugin managers
read tags directly from the repository, so publishing a release means tagging a commit
on `main` and creating a GitHub Release from it.

## Choosing the number

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/),
which determines the bump:

| commit type                            | bump  | example              |
| -------------------------------------- | ----- | -------------------- |
| `fix:`                                 | patch | `1.1.0` → `1.1.1`    |
| `feat:`                                | minor | `1.1.0` → `1.2.0`    |
| `feat!:` or a `BREAKING CHANGE:` footer | major | `1.1.0` → `2.0.0`    |

Anything else (`chore:`, `docs:`, `refactor:`) doesn't warrant a release on its own.

A change is breaking if an existing `config.json`, a `setup()` call, or a documented
keymap stops working the way it used to.

## Cutting a release

Review what has landed since the last tag, pick the bump, then:

```sh
git checkout main
git pull

# see what is being released
git log --oneline $(git describe --tags --abbrev=0)..HEAD

git tag -a v1.2.0 -m "v1.2.0"
git push origin v1.2.0

gh release create v1.2.0 --title "v1.2.0" --generate-notes
```

`--generate-notes` builds the notes from merged pull requests. Edit them afterwards
when a change deserves more explanation than its PR title gives.

## What users get

Once tags exist, `lazy.nvim` can follow releases instead of `main`:

```lua
{
  "dimaportenko/project-cli-commands.nvim",
  version = "*",      -- latest stable release
  -- version = "^1.0.0",  -- semver range
  -- tag = "v1.0.0",      -- exact tag
  -- pin = true,          -- never update
}
```

Because `version` resolves against published tags, a tag that turns out to be broken
sticks with everyone who pinned to it until the next one. Prefer releasing a follow-up
patch over deleting or moving a tag that has already been pushed.
