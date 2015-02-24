

* need to add custom tab completion for aliases, builtins, shell commands, and file system commands

* support user-specified gems to install (so they're available for rc files)

* truncate the prompt so you can type long commands
* don't overwrite timestamp? (or have it disappear when you write over it altogether, similar to ZSH)
* have configurable prompt components
* interact with the "World" rather than just operating on string contents
* communicate exit codes to user (w/color)
* allow for a multiline smart prompt or at least some kind of status notifications
* get readline's history to work between start and restops
* fix reload! so it works again
* handle stderr
* intelligently handle pipes that show up in ruby blocks, e.g. map{ |a,b| a }
* Fix shell builtins like pushd/popd. :(
* Support user-requested background processes, e.g. "ls &"
* You cannto load yap if you are within yap. Handle the error or let it happen.

Others requests.

*  Sam: Better text movement/manipulation tools
** e.g. delete-forward-word
** I spend a lot of time using my arrow keys (or equivalents) in my terminal and I hate that.

* Jonah: The one thing that seems passive agressive to me is the lack of confirmation when something has gone well. You get barked at if things don’t work, but when they do you get nothing. I think that’s a BS way to behave. Everything. The long running processes give you feedback. Something short and sweet returns nothing. Consistent behavior would be nice.

* EJ reply:  my shell’s prompt color changes depending on the success/failure of the last command

* Sam: a way to say "make the last 7 items in my history into a script/macro”

* Sam: I want my history to be dependent on the project, so when I go into an old project I can see the commands I had been running there months ago.

* Sam: integration with ruby/python/etc interpreters and my editor, so I can interact with stack traces -- even just to open file and jump to line number.

* Sam: sublime style fuzzy autocomplete* Sam: (ooh, but what about an 'oh shit please pipe this through less/paginate this' that you could run after a command has started. 6/3)

* @dylanized: themeable
* @dylanized: browser-based
* @dylanized: bookmarks
