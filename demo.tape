# VHS tape for session-tab-namer demo GIF
# Run: brew install vhs && vhs demo.tape
# Output: demo.gif

Output demo.gif

Set Shell "zsh"
Set FontSize 16
Set Width 800
Set Height 400
Set Theme "Catppuccin Mocha"
Set Padding 20

# Show a simulated tab bar with generic names
Type "# Before: all your Claude Code tabs look the same"
Enter
Sleep 500ms
Type "# claude  |  claude  |  claude  |  claude"
Enter
Sleep 1.5s

# Show the hook setting a fallback name
Type "# SessionStart hook fires instantly:"
Enter
Sleep 500ms
Type@100ms "printf '\033]0;claude:a3f2c1\007' > /dev/tty"
Enter
Sleep 1s

# Show Claude renaming once objective is clear
Type "# You say: 'help me set up a multi-agent flow in embabel'"
Enter
Sleep 1s
Type "# Claude auto-renames the tab:"
Enter
Sleep 500ms
Type@100ms "printf '\033]0;build:embabel-multi-agent\007' > /dev/tty"
Enter
Sleep 1.5s

# Show multiple named tabs
Type ""
Enter
Type "# After: every tab tells you what it's for"
Enter
Sleep 500ms
Type "# build:embabel-multi-agent | research:jwt-rotation | debug:pytest-flaky"
Enter
Sleep 3s
