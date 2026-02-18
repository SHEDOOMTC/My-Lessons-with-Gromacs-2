# Boxing, Solvation and Adding ions to your Systems

------------

**Prerequisites**

1.  There must be a a folder with  n subfolders named dir{0..n}

2.  Copy the cordinate file (.gro) of the various walkers into each subfolder (this must be the only cordinate file present)

3.  Copy all other needed file (topology files)

4.  Copy the mdp file (ions.mdp) into the main folder

-------------

**Usage:**

´´´bash

#clone repository

cp box-solv-ion/solvate_ions.sh

chmod +x solvate_ions.sh

./solvate_ions.sh

´´´

--------

**Output files**

You will have a cordinate file (ions.gro) which is solvated and neutralized with ions

----------

**Notes**

If you want different -pname, -nname and -conc flags in the genion, edit the bash file

