# History Addon

The History addon is provides primitive history capabilities:

* Loads history from ~/.yap/history when yap is loaded
* Saves history to ~/.yap/history when yap exits
* Saving is an append-only operation
* ~/.yap/history is in YAML format

## Shell Functions

The history addon provides the `history` shell function that prints the contents of the history.

## Limitations

The history addon currently does not support any kind of advanced history operations.
