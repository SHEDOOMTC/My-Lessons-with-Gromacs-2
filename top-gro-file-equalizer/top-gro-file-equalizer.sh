#!/bin/bash

echo "Enter directory pattern (e.g. 3-*):"
read dir_pattern

echo "Enter residue name (e.g. SOL, NA, K, CL):"
read resname

echo "Enter filename to search inside directories (e.g. top.top):"
read ext

echo "Enter GRO filename inside each directory (e.g. 5-1-solvate.gro):"
read gro_name

echo "Dry run? (y/n):"
read dry
dry_run=false
if [[ "$dry" == "y" ]]; then
    dry_run=true
    echo "DRY RUN MODE ENABLED — no files will be modified."
fi

# ----------------------------------------
# 2. Expand directory glob safely
# ----------------------------------------
dirs=( $dir_pattern )

if [ ${#dirs[@]} -eq 0 ]; then
    echo "Error: No directories match '$dir_pattern'"
    exit 1
fi

echo "Directories to search:"
printf "  %s\n" "${dirs[@]}"

# ----------------------------------------
# 3. Collect all residue counts per file
# ----------------------------------------
declare -A res_values

while IFS= read -r file; do
    val=$(grep "^$resname" "$file" | tail -1 | awk '{print $2}')
    if [ -n "$val" ]; then
        res_values["$file"]="$val"
    fi
done < <(find "${dirs[@]}" -type f -name "$ext")

if [ ${#res_values[@]} -eq 0 ]; then
    echo "No $resname lines found in any matching files."
    exit 1
fi

# ----------------------------------------
# 4. Summary BEFORE
# ----------------------------------------
echo ""
echo "===================="
echo " SUMMARY (Before) "
echo "===================="
printf "%-40s %10s\n" "File" "$resname"
printf "%-40s %10s\n" "----------------------------------------" "----------"

for f in "${!res_values[@]}"; do
    printf "%-40s %10s\n" "$f" "${res_values[$f]}"
done

# ----------------------------------------
# 5. Determine minimum
# ----------------------------------------
min_val=$(printf "%s\n" "${res_values[@]}" | sort -n | head -1)

echo ""
echo "Lowest $resname value found: $min_val"
echo ""

echo "$min_val" > least-${resname}.txt

# ----------------------------------------
# 6. Compute per-directory differences
# ----------------------------------------
echo "Computing per-directory $resname differences..."

declare -A diff_values

for f in "${!res_values[@]}"; do
    val="${res_values[$f]}"
    diff=$(( val - min_val ))

    dir_name=$(dirname "$f")
    dir_name=$(basename "$dir_name")

    outfile="temp${dir_name}.txt"
    echo "$diff" > "$outfile"

    diff_values["$dir_name"]="$diff"

    echo "  $outfile  ←  difference $val - $min_val = $diff"
done

if $dry_run; then
    echo ""
    echo "DRY RUN — No .gro files will be modified."
    exit 0
fi


# ----------------------------------------
# Update TOP file for each directory
# ----------------------------------------
for dir_name in "${!diff_values[@]}"; do
    diff="${diff_values[$dir_name]}"
    top_file="$dir_name/$ext"

    if [ -f "$top_file" ]; then
        echo "Updating TOP file: $top_file"

        count=$(grep -E "^[[:space:]]*$resname[[:space:]]+[0-9]+" "$top_file" | awk '{print $2}')

        if [ -n "$count" ]; then
            new_count=$((count - diff))
            echo "  $resname count: $count → $new_count"

            sed -i "s/^\([[:space:]]*$resname[[:space:]]*\)[0-9]\+/\1$new_count/" "$top_file"
        else
            echo "  No $resname count found — skipping"
        fi
    else
        echo "  No TOP file found in $dir_name — skipping"
    fi
done

# ----------------------------------------
# 8. Trim GRO files
# ----------------------------------------

echo ""
echo "Processing GRO files..."

for dir_name in "${!diff_values[@]}"; do
    diff="${diff_values[$dir_name]}"
    gro_file="$dir_name/$gro_name"
    output_file="$dir_name/ions_new.gro"

    if [ ! -f "$gro_file" ]; then
        echo "  No GRO file found in $dir_name — skipping"
        continue
    fi

    # If diff is zero → just copy the file
    if [ "$diff" -eq 0 ]; then
        echo "  $gro_file: diff = 0 → copying to ions_new.gro"
        cp "$gro_file" "$output_file"
        continue
    fi

    # Special rule for SOL
    delete_count="$diff"
    if [ "$resname" == "SOL" ]; then
        delete_count=$(( diff * 3 ))
    fi

    echo "  Processing $gro_file (remove last $delete_count $resname lines)"

    mapfile -t res_lines < <(
        grep -n "^[[:space:]]*[0-9]\+[[:space:]]*$resname[[:space:]]" "$gro_file" \
        | tail -n "$delete_count" \
        | cut -d: -f1
    )

    if [ "${#res_lines[@]}" -eq 0 ]; then
        echo "    No $resname lines found — skipping"
        continue
    fi

    first_line=${res_lines[0]}
    last_line=${res_lines[-1]}

    echo "    Deleting lines $first_line to $last_line"
    sed -i.bak "${first_line},${last_line}d" "$gro_file"

    # Update atom count
    atom_count=$(sed -n '2p' "$gro_file")

    atoms_removed="$diff"
    if [ "$resname" == "SOL" ]; then
        atoms_removed=$(( diff * 3 ))
    fi

    new_count=$((atom_count - atoms_removed))

    echo "    Updating atom count: $atom_count → $new_count"
    sed -i "2s/.*/$new_count/" "$gro_file"

    # Now run editconf on the modified file
    gmx editconf -f "$gro_file" -o "$output_file"
done

# ----------------------------------------
# 9. Summary AFTER
# ----------------------------------------
echo ""
echo "===================="
echo " SUMMARY (After) "
echo "===================="
printf "%-40s %10s\n" "File" "$resname"
printf "%-40s %10s\n" "----------------------------------------" "----------"

for f in "${!res_values[@]}"; do
    printf "%-40s %10s\n" "$f" "$min_val"
done
