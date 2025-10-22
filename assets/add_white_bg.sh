#!/bin/bash
# Create a white background version of the logo

# Get dimensions of original
WIDTH=$(sips -g pixelWidth spark_logo.png | tail -1 | awk '{print $2}')
HEIGHT=$(sips -g pixelHeight spark_logo.png | tail -1 | awk '{print $2}')

# Create white background image
sips -c $HEIGHT $WIDTH --setProperty format png -s formatOptions default --out spark_white_bg.png spark_logo.png 2>/dev/null

# For the icon, we'll make a square version with padding
SIZE=1024
PAD=100
LOGO_SIZE=$((SIZE - PAD * 2))

# Create temporary resized logo
sips --resampleWidth $LOGO_SIZE spark_logo.png --out spark_logo_resized.png 2>/dev/null

echo "Created files for icon generation"
