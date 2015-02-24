leodown
=======
A lazy-man script for checking bunch of Leopard-Raws objects for update.

## Capability
1. List ongoing shows.
2. Search and add anime series to watch list.
3. Check and download newly uploaded objects without duplication.
4. Type leodown.pl -h to view the document.

## Cross Platform
I recently separated the original shell script into two: leodown.sh and leodown.pl.
1. For linux, leodown.sh uses Libnotify to send notifications output by leodown.pl.
2. On all platforms, leodown.pl will do text outputs to STDOUT and STDERR using UTF8:
	1. STDOUT: prefixed with MSG or ADD for notification.
	2. STDERR: debug messages & list outputs.
