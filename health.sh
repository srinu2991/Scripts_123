#!/bin/bash

# Define the column names
column_names=("Application Components" "Overall Status" "CPU" "Memory" "Storage" "Comments")

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
for col_name in "${column_names[@]}"; do
    echo "    <th>$col_name</th>" >> table.html
done
echo "  </tr>" >> table.html

# Generate the rows with placeholder content
for (( i=1; i<=15; i++ )); do
    echo "  <tr>" >> table.html
    for (( j=0; j<6; j++ )); do
        echo "    <td>Row $i, Column $((j+1))</td>" >> table.html
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

# Define email parameters
EMAIL_SUBJECT="Generated HTML Table"
EMAIL_TO="recipient@example.com"
EMAIL_FROM="sender@example.com"

# Send the email
sendmail -t <<EOF
To: $EMAIL_TO
Subject: $EMAIL_SUBJECT
MIME-Version: 1.0
Content-Type: text/html

$(cat table.html)
EOF

echo "Email sent to $EMAIL_TO"
