(cat <<EOF
From: sender@example.com
To: recipient@example.com
Subject: HTML Email
MIME-Version: 1.0
Content-Type: text/html; charset=UTF-8
Content-Transfer-Encoding: base64

$(echo "<html><body><h1>Hello, World!</h1><p>This is an HTML email.</p></body></html>" | base64)
EOF
) | sendmail -t
