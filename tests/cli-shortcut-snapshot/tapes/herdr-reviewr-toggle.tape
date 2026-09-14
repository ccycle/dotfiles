# Records modules/herdr/config.toml's `prefix+ctrl+r` -> persiyanov.reviewr.toggle
# binding actually firing. Launches herdr itself as the foreground
# interactive client of a disposable named session (via $SESSION_NAME,
# exported by scripts/run.sh) - not the remote `pane send-keys`/
# `terminal attach` control path, which never reaches herdr's keybinding
# router. See ../design.md.
Require herdr

Set Shell "bash"
Set FontSize 16
Set Width 1200
Set Height 700

Type "herdr --session $SESSION_NAME"
Enter
Sleep 2s

Ctrl+B
Sleep 300ms
Ctrl+R
Sleep 1500ms
