#!/bin/bash

# Define the row names
row_names=("Application Components" "Overall Status" "CPU" "Memory" "Storage" "Comments")

# Create the HTML file
cat <<EOF > table.html
<!DOCTYPE html>
<html>
<head>
    <title>Table</title>
    <style>
        table {
            width: 100%;
            border-collapse: collapse;
        }
        table, th, td {
            border: 1px solid black;
        }
        th, td {
            padding: 10px;
            text-align: left;
        }
    </style>
</head>
<body>

<h2>Generated Table</h2>

<table>
EOF

# Generate the header row
echo "  <tr>" >> table.html
for (( i=0; i<15; i++ )); do
    echo "    <th>Header $((i+1))</th>" >> table.html
done
echo "  </tr>" >> table.html

# Generate the rows with predefined names
for (( i=0; i<5; i++ )); do
    echo "  <tr>" >> table.html
    for (( j=0; j<15; j++ )); do
        if (( j == 0 )); then
            echo "    <td>${row_names[i]}</td>" >> table.html
        else
            echo "    <td>Cell $((i+1)),$((j+1))</td>" >> table.html
        fi
    done
    echo "  </tr>" >> table.html
done

# Close the HTML tags
cat <<EOF >> table.html
</table>

</body>
</html>
EOF

echo "HTML table generated in table.html"
