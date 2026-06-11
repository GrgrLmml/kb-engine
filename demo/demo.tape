# README screencast: git clone -> install.sh -> Claude session recalling from the KB.
# Renders demo/demo.gif. Re-render with: vhs demo/demo.tape
#
# Runs in a PERSISTENT throwaway HOME (/tmp/kb-demo-home) — the real ~/.claude is
# never touched, and a one-time login there survives re-renders:
#     HOME=/tmp/kb-demo-home claude     ->  /login   (do this once, before rendering)
#
# The hidden setup mirrors this working tree locally and adds a git insteadOf
# rewrite in the FAKE home's gitconfig, so the visible `git clone https://...`
# resolves locally — same content, honest output, works before pushing.
#
# The session is live model output — review the GIF before committing; nudge the
# final Sleep if the answer gets cut off. After rendering, trim the static tail
# (find where the image freezes, then cut ~3s after that):
#     ffmpeg -i demo/demo.gif -vf "freezedetect=n=0.0005:d=1.5" -f null - 2>&1 | grep freeze_start
#     ffmpeg -i demo/demo.gif -t <freeze+3> -filter_complex \
#       "[0:v]split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4" out.gif

Output demo/demo.gif

Set Shell bash
Set FontSize 17
Set Width 1280
Set Height 780
Set Padding 16
Set TypingSpeed 25ms
Set Theme "GitHub Dark"

# --- invisible setup ----------------------------------------------------------
Hide
Type `export HOME=/tmp/kb-demo-home; export PATH="$HOME/.local/bin:$PATH"; rm -rf /tmp/kb-demo /tmp/kb-demo-src; mkdir -p /tmp/kb-demo-home /tmp/kb-demo /tmp/kb-demo-src/kb-engine.git; [ -f "$HOME/.claude.json" ] || printf '{"hasCompletedOnboarding": true, "theme": "dark", "autoUpdates": false}\n' > "$HOME/.claude.json"; cp -R "${KB_ENGINE_DIR:-$PWD}/." /tmp/kb-demo-src/kb-engine.git/; cd /tmp/kb-demo-src/kb-engine.git; rm -rf .git kb-data demo/kb-data/.index demo/kb-data/.git demo/*.gif; git init -q; git add -A; git -c user.email=demo@kb -c user.name=demo commit -qm "kb-engine"; git config --global url."file:///tmp/kb-demo-src/".insteadOf "https://github.com/GrgrLmml/"; cd /tmp/kb-demo; clear`
Enter
Sleep 6s
Show

# --- clone, install, ask ------------------------------------------------------
Type "git clone https://github.com/GrgrLmml/kb-engine.git"
Enter
Sleep 2s

Type "cd kb-engine && ./install.sh --yes --kb-data demo/kb-data"
Enter
Sleep 4s

Type "claude"
Enter
Sleep 5s

Type "What did we decide about the Orbit feed poller, and why did it change?"
Enter
Sleep 40s
