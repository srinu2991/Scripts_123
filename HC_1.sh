#!/bin/bash

# Define the column names
column_names=("Application" "Last checked" "Status")

# Define the first column values
first_column_values=("01. Worker Portal" "02. Customer Portal" "03. Provider Portal" "04. Reporting Portal" "05. EASL Endpoint" "06. Business Rules Engine Endpoint" "07. Adobe Notices Web Services" "08. ForgeRock" "09. MCI Endpoint" "10. Worker Portal DB RW Mode")

# Create the HTML file
cat <<EOF > table.html
<!DOCTYPE html>
<html>
<head>
    <title>Table</title>
    <style>
        table {
            width: 30%;
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

<h2><u>Generated Health Check Table</u></h2>

<h2>Application Health Report Summary</h2>

<table>
EOF

# Generate the header row
echo "  <tr>" >> table.html
for col_name in "${column_names[@]}"; do
    echo "    <th>$col_name</th>" >> table.html
done
echo "  </tr>" >> table.html

# Generate the rows with first column values and placeholder content
for (( i=0; i<10; i++ )); do
    echo "  <tr>" >> table.html
    for (( j=0; j<3; j++ )); do
        if (( j == 0 )); then
            echo "    <td>${first_column_values[i]}</td>" >> table.html
        else
            echo "    <td>Row $((i+1)), Column $((j+1))</td>" >> table.html
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



111111111111111111111111111111111111111111111111111111
#!/bin/bash

# Define the column names
column_names=("Application" "Status" "Last Checked")

# Define the first column values
first_column_values=("Worker Portal" "Customer Portal" "Provider Portal" "Reporting Portal" "EASL Endpoint" "Business Rules Engine Endpoint" "Adobe Notices Web Services" "ForgeRock" "MCI Endpoint" "Worker Portal DB RW Mode")

# Input CSV file
INPUT_FILE="status.csv"

# Output HTML file
OUTPUT_FILE="table.html"

# Create the HTML file
cat <<EOF > $OUTPUT_FILE
<!DOCTYPE html>
<html>
<head>
    <title>Table</title>
    <style>
        table {
            width: 50%;
            border-collapse: collapse;
        }
        table, th, td {
            border: 1px solid black;
        }
        th, td {
            padding: 10px;
            text-align: left;
        }
        h2.center {
            text-align: center;
        }
    </style>
</head>
<body>

<h2 class="center"><u>Generated Health Check Table</u></h2>

<h2>Application Health Report Summary</h2>

<table>
EOF

# Generate the header row
echo "  <tr>" >> $OUTPUT_FILE
for col_name in "${column_names[@]}"; do
    echo "    <th>$col_name</th>" >> $OUTPUT_FILE
done
echo "  </tr>" >> $OUTPUT_FILE

# Read the CSV file and generate rows
tail -n +2 $INPUT_FILE | while IFS=, read -r ITEM STATUS TIMESTAMP; do
    echo "  <tr>" >> $OUTPUT_FILE
    echo "    <td>$ITEM</td>" >> $OUTPUT_FILE
    echo "    <td>$STATUS</td>" >> $OUTPUT_FILE
    echo "    <td>$TIMESTAMP</td>" >> $OUTPUT_FILE
    echo "  </tr>" >> $OUTPUT_FILE
done

# Close the HTML tags
cat <<EOF >> $OUTPUT_FILE
</table>

</body>
</html>
EOF

echo "HTML table generated in $OUTPUT_FILE"

