#!/bin/bash

# Function to generate a random password
generate_password() {
    local length=$1
    # Define the character set for the password
    local char_set="A-Za-z0-9!@#$%^&*()-_=+[]{}|;:,.<>?"

    # Generate a random password using the specified length
    tr -dc "$char_set" < /dev/urandom | head -c "$length"
    echo
}

# Check if the number of arguments is correct
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <password_length> <number_of_passwords>"
    exit 1
fi

# Assign command line arguments to variables
password_length=$1
num_passwords=$2

# Ensure the password length is at least 8 characters
if [ "$password_length" -lt 8 ]; then
    echo "Password length must be at least 8 characters."
    exit 1
fi

# Generate the specified number of passwords
for ((i=1; i<=$num_passwords; i++)); do
    generate_password "$password_length"
done