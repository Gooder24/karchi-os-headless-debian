# fastfetch at every interactive login, on the console and over SSH.
case $- in *i*) command -v fastfetch > /dev/null && fastfetch ;; esac
