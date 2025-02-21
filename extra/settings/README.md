Veshell settings congiguration are stored inside json files.

Only overrides from the default values are stored.

Location of thoses files can be defined assigning `VESHELL_CONFIG_DIR` environment variable.
If this variable is not defined it default to `XDG_CONFIG_HOME/veshell` or `~/.config/veshell` if `XDG_CONFIG_HOME` is not defined.

The location of defaults congiguration files can be defined assigning `VESHELL_DEFAULT_CONFIG_DIR` environment variable.
If this variable is not defined it default to the packaged one. Overriding this could be useful for distrib packagers.