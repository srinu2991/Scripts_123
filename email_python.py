import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

# Email configuration
smtp_server = 'smtp.office365.com'
smtp_port = 587
sender_email = 'your-email@outlook.com'
recipient_email = 'recipient-email@example.com'

# Read HTML content from file
with open('your_html_file.html', 'r') as file:
    html_content = file.read()

# Email subject
subject = 'Subject of the Email'

# Create message container
msg = MIMEMultipart('alternative')
msg['From'] = sender_email
msg['To'] = recipient_email
msg['Subject'] = subject

# Record the MIME type of the HTML part
part1 = MIMEText(html_content, 'html')

# Attach the HTML part into the message container
msg.attach(part1)

# Send the message via the SMTP server
try:
    server = smtplib.SMTP(smtp_server, smtp_port)
    server.starttls()  # Upgrade the connection to a secure encrypted SSL/TLS connection
    server.sendmail(sender_email, recipient_email, msg.as_string())
    server.quit()
    print("Email sent successfully.")
except Exception as e:
    print(f"Failed to send email. Error: {str(e)}")
