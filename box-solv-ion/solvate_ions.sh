#!/bin/bash

main_dir=./

subfolders=( $(ls -d dir*/ 2>/dev/null) )

for folder in "${subfolders[@]}"; do
  folder_name="${folder%/}"  # e.g. "dir0"
  echo "Processing folder: $folder_name"

  cd "$folder" || { echo "Failed to enter $folder"; continue; }

  input_gro=$(ls *.gro 2>/dev/null | head -n1) # *.gro the only gro file in that folder
  topology_file="top.top"
  mdp_file="ions.mdp"

  cp ../ions.mdp .

  # Check if required files exist
  if [[ ! -f "$input_gro" ]]; then
    echo "Input GRO file $input_gro not found in $folder_name, skipping."
    cd ..
    continue
  fi
  if [[ ! -f "$topology_file" ]]; then
    echo "Topology file $topology_file not found in $folder_name, skipping."
    cd ..
    continue
  fi
  if [[ ! -f "$mdp_file" ]]; then
    echo "MDP file $mdp_file not found in $folder_name, skipping."
    cd ..
    continue
  fi


  #====== 1. Add box =========

  box_out="box.gro"

  gmx editconf -f "$input_gro" -o "$box_out" -c -d 1.2 -bt cubic


  #====== 2. Solvate ==========

  solvate_out="solvate.gro"
  
  gmx solvate -cp "$box_out" -cs spc216.gro -p "$topology_file" -o "$solvate_out"

  if [[ $? -ne 0 ]]; then
    echo "Solvate failed in $folder_name, skipping."
    cd ..
    continue
  fi

  #====== 3. Make index file ========

  make_ndx_out="index.ndx"

  (echo 'q' && echo) | gmx make_ndx -f "$solvate_out" -o "$make_ndx_out"

  if [[ $? -ne 0 ]]; then
    echo "make_ndx failed in $folder_name, skipping."
    cd ..
    continue
  fi


  #====== 4. Grompp preprocessing to generate ion.tpr for genions ========

  tpr_out="ions.tpr"

  gmx grompp -f "$mdp_file" -c "$solvate_out" -r "$solvate_out" -p "$topology_file" -n "$make_ndx_out" -o "$tpr_out" -maxwarn 1000


  if [[ $? -ne 0 ]]; then
    echo "grompp failed in $folder_name, skipping."
    cd ..
    continue
  fi


  #====== 5. Add Ions ===============

  output_ions_file="ions.gro"
  (echo "SOL" && echo) | gmx genion -s "$tpr_out" -n "$make_ndx_out" -p "$topology_file" -pname K -nname CL -conc 0.1 -neutral -o "$output_ions_file"

  if [[ $? -ne 0 ]]; then
    echo "Genions failed in $folder_name, skipping."
    cd ..
    continue
  fi


  cd ..
done






