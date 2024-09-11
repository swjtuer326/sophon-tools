#!/bin/bash
search_dir="./"
if [ $# -eq 1 ]; then
  search_dir="$1"
fi

file_extensions=("cpp" "c" "h" "hpp")
for ext in "${file_extensions[@]}"
do
  find "$search_dir" -maxdepth 1 -type f -name "*.$ext" -exec astyle --options=.astylerc {} \;
done
echo "Formatting completed."
