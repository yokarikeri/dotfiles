# ================================
#  Zsh Options
#  https://zsh.sourceforge.io/Doc/Release/Options-Index.html
# ================================

#
# 16.2.1 Changing Directories
# https://zsh.sourceforge.io/Doc/Release/Options.html#Changing-Directories
#
setopt AUTO_CD           # Type a directory name alone to cd into it.
setopt AUTO_PUSHD        # Push the old directory onto the stack on cd.
setopt CD_SILENT         # Do not print the working directory after cd.
setopt CDABLE_VARS       # Allow cd to expand variables as directory names.
setopt PUSHD_IGNORE_DUPS # Do not push duplicate directories.
setopt PUSHD_SILENT      # Do not print the stack after pushd/popd.
setopt PUSHD_TO_HOME     # pushd with no argument goes to $HOME.

#
# 16.2.2 Completion
# https://zsh.sourceforge.io/Doc/Release/Options.html#Completion-4
#
setopt ALWAYS_TO_END     # Move cursor to end of word after completion.
setopt COMPLETE_IN_WORD  # Complete from both ends of the cursor.
unsetopt LIST_BEEP       # No beep on an ambiguous completion.

#
# 16.2.3 Expansion and Globbing
# https://zsh.sourceforge.io/Doc/Release/Options.html#Expansion-and-Globbing
#
setopt EXTENDED_GLOB     # Enable #, ~, ^ as glob pattern operators.
unsetopt CASE_GLOB       # Case-insensitive globbing.

#
# 16.2.4 History
# https://zsh.sourceforge.io/Doc/Release/Options.html#History
#
setopt EXTENDED_HISTORY       # Write the history file as ':start:elapsed;command'.
setopt SHARE_HISTORY          # Share history in real time across all sessions.
setopt HIST_EXPIRE_DUPS_FIRST # Expire duplicate entries first when trimming history.
setopt HIST_REDUCE_BLANKS     # Remove superfluous whitespace from history entries.
setopt HIST_FIND_NO_DUPS      # Never show duplicate entries during history search.
setopt HIST_SAVE_NO_DUPS      # Do not write duplicate entries to the history file.
setopt HIST_IGNORE_DUPS       # Do not record the same command as the previous one.
setopt HIST_IGNORE_ALL_DUPS   # Remove older duplicate entries from history.
setopt HIST_IGNORE_SPACE      # Do not record commands that start with a space.
setopt BANG_HIST              # Enable ! history expansion.
setopt HIST_VERIFY            # Show the expanded command before executing it.

#
# 16.2.6 Input/Output
# https://zsh.sourceforge.io/Doc/Release/Options.html#Input_002fOutput
#
setopt CORRECT            # Offer spelling correction for command names.
setopt IGNORE_EOF         # Require explicit 'exit' instead of C-d.
unsetopt FLOW_CONTROL     # Disable C-s/C-q flow-control characters.
# Free C-s and C-q for key binding use.
[[ -r ${TTY:-} && -w ${TTY:-} && $+commands[stty] == 1 ]] && stty -ixon <$TTY >$TTY
unsetopt CLOBBER          # Do not silently overwrite files with >; use >| instead.
setopt INTERACTIVE_COMMENTS # Allow # comments in interactive shells.

#
# 16.2.7 Job Control
# https://zsh.sourceforge.io/Doc/Release/Options.html#Job-Control
#
setopt AUTO_RESUME       # Resume a suspended job when its name is typed.
setopt LONG_LIST_JOBS    # List jobs in the long format.
unsetopt BG_NICE         # Do not lower the priority of background jobs.
unsetopt CHECK_JOBS      # Do not report job status when the shell exits.
unsetopt HUP             # Do not send SIGHUP to jobs when the shell exits.

#
# 16.2.12 Zle
# https://zsh.sourceforge.io/Doc/Release/Options.html#Zle
#
unsetopt BEEP            # No beep on ZLE errors.
if [[ ${(L)LANG} == *utf-8* ]]; then
  setopt COMBINING_CHARS # Correctly display UTF-8 combining characters.
fi
