() {
  local _conf
  for _conf ("$@") . "$_conf"
} $ZDOTDIR/conf.d/*.zsh(N.)
