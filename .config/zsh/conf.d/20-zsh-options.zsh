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
unsetopt EXTENDED_GLOB   # #, ~, ^ as glob pattern operators.
unsetopt CASE_GLOB       # Case-insensitive globbing.

#
# 16.2.4 History
# https://zsh.sourceforge.io/Doc/Release/Options.html#History
#
setopt EXTENDED_HISTORY       # Write the history file as ':start:elapsed;command'.
setopt SHARE_HISTORY          # Share history in real time across all sessions.
setopt HIST_EXPIRE_DUPS_FIRST # Expire duplicate entries first when trimming history.
setopt HIST_REDUCE_BLANKS     # Remove superfluous whitespace from history entries.
setopt HIST_IGNORE_SPACE      # Do not record commands that start with a space.
setopt HIST_FIND_NO_DUPS      # Never show duplicate entries during history search.
unsetopt HIST_SAVE_NO_DUPS    # Do not write duplicate entries to the history file.
unsetopt HIST_IGNORE_DUPS     # Do not record the same command as the previous one.
unsetopt HIST_IGNORE_ALL_DUPS # Remove older duplicate entries from history.
unsetopt BANG_HIST            # Enable ! history expansion.
setopt HIST_VERIFY            # Show the expanded command before executing it. (Do not disable for safety reasons.)

#
# 16.2.5 Initialisation
# https://zsh.sourceforge.io/Doc/Release/Options.html#Initialisation
#

#
# 16.2.6 Input/Output
# https://zsh.sourceforge.io/Doc/Release/Options.html#Input_002fOutput
#
setopt CORRECT            # Correcting spelling mistakes in commands
setopt IGNORE_EOF         # ignore C-D logout
unsetopt FLOW_CONTROL     # ignore C-Q start / C-S stop
# Clear the IXON flag at the kernel level.
# Bypass ^S/^Q in all processes, including Zsh.
[[ -r ${TTY:-} && -w ${TTY:-} && $+commands[stty] == 1 ]] && stty -ixon <$TTY >$TTY
unsetopt CLOBBER            # Do not silently overwrite files with >; use >| instead.
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
# 16.2.8 Prompting
# https://zsh.sourceforge.io/Doc/Release/Options.html#Prompting
#

#
# 16.2.9 Scripts and Functions
# https://zsh.sourceforge.io/Doc/Release/Options.html#Scripts-and-Functions
#

#
# 16.2.10 Shell Emulation
# https://zsh.sourceforge.io/Doc/Release/Options.html#Shell-Emulation
#

#
# 16.2.11 Shell State
# https://zsh.sourceforge.io/Doc/Release/Options.html#Shell-State
#

#
# 16.2.12 Zle
# https://zsh.sourceforge.io/Doc/Release/Options.html#Zle
#
unsetopt BEEP            # No beep on ZLE errors.
if [[ ${(L)LANG} == *utf-8* ]]; then
  setopt COMBINING_CHARS # Correctly display UTF-8 combining characters.
fi
