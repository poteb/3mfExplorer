Project description

Name: 3MF Explorer

This project uses bash scripts to generate a HTML page. The page will show icons of 3MF files that can be clicked and opened.

It will consist of scripts that look through .3mf files and uses the names and icons to generate a static html file that follow the structure of the folders of the 3mf files.

The 3mffolders.md has a list of which folders to look in. The folders can point to anywhere on the system.
If a folder ends with a * then it's a cascade search through all subdirectories as well. If no *, then it's just the root of the folder.

Each folder in 3mffolders.md will have its own section in the output. Each subdirectory (if using *) will have a subsection under this top folder section.
