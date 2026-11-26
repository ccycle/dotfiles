# brew-nix Design

## Why google-japanese-ime Is Wrapped

The pkg payload links its `.app` shortcuts to absolute `/Library/Input Methods` paths, which exist only where Google's own installer ran.
On a fresh machine those links dangle and nix-darwin's `/Applications/Nix Apps` rsync aborts, so a copy re-points them at the package's own `.app`.

## Rejected Alternatives

- `postInstall` on the package itself: it forces a rebuild of the inner package, whose dmg URL is unversioned and whose upstream content no longer matches the pinned hash.

## Constraints

- The inner package builds only while its output or source is still in a store or cache; a fresh fetch fails until the pinned hash is updated.
