# Quick bash utility for compiling the correct Python version


## Options

1 - install python (version-code) 
2 - remove python (version-code)


## Notes
If you have python 3.10.0, and you install python 3.10.12 with this utility - new installation will not be visible or properly linked because they are both called by 'python3.10'.
Make sure to have only one major python version installed at a time. 

Installation is done by downloading source code for selected version, updating packages and installing compilation librarires, enabling optimizations and compiling python - all packages and downloads are cleaned after verified installation.
