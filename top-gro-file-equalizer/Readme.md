# top-gro-file-equalizer

----------

**Expectations**

1.  There must be a a folder with  n subfolders (walkers) named in a consistent pattern (dir*, walker* etc)

2.  Each walker must contain a cordinate file from the prior genion with same name (the previous [box-solve-ion](../box-solv-ion/solvate_ions.sh) script does the job)

3.  Ensure all needed topolgy and files are present

--------

**Script**

The [top-gro-file-equalizer script](../top-gro-file-equalizer.sh) accepts the following arguments interactively:

1.  Directory pattern (dir*, walker* etc)

2.  Residue name to edit (usually SOL but can also be NA, K, CL)

3.  Topology file to search and modify (".top" file)

4.  Cordinate file to search and modify (".gro")

5.  A chance for a --dry-run (if yes, then it display the intended changes but makes none)

---------

**How the script works**

1.  The script searches the topology file for the residue name (eg. SOL) and then compares its number across all the walkers

2.  It identifies the walker with the least value and computes the difference for other walkers

3.  It uses this difference to edit the topology file and the .gro file to make them uniform

4.  Then finally uses "gmx editconf" to renumber the .gro file

----------

**Note**

Always execute the --dry-run first to see whether any changes are required and what these changes are





