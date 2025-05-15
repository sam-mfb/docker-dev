#!/bin/bash

# Display ANSI color codes
echo "ANSI Color Codes"
echo "================"

# Basic colors (0-7)
echo -e "\nBasic colors (0-7):"
for i in {0..7}; do
  echo -e "\e[3${i}m3${i}: Foreground\e[0m \e[4${i}m4${i}: Background\e[0m"
done

# Bright colors (0-7)
echo -e "\nBright colors (90-97, 100-107):"
for i in {0..7}; do
  echo -e "\e[9${i}m9${i}: Foreground\e[0m \e[10${i}m10${i}: Background\e[0m"
done

# Text attributes
echo -e "\nText attributes:"
echo -e "\e[0m0: Reset\e[0m"
echo -e "\e[1m1: Bold\e[0m"
echo -e "\e[2m2: Dim\e[0m"
echo -e "\e[3m3: Italic\e[0m"
echo -e "\e[4m4: Underline\e[0m"
echo -e "\e[5m5: Blink\e[0m"
echo -e "\e[7m7: Reverse\e[0m"
echo -e "\e[8m8: Hidden\e[0m (hidden)"
echo -e "\e[9m9: Strikethrough\e[0m"

# 256 colors
echo -e "\n256 colors (16-255):"
for i in {16..255}; do
  printf "\e[38;5;%sm %3s \e[0m" $i $i
  [ $(( (i-15) % 6)) -eq 0 ] && echo
done

# RGB colors example
echo -e "\nRGB color examples:"
echo -e "\e[38;2;255;0;0mRed (255,0,0)\e[0m"
echo -e "\e[38;2;0;255;0mGreen (0,255,0)\e[0m"
echo -e "\e[38;2;0;0;255mBlue (0,0,255)\e[0m"
echo -e "\e[38;2;255;255;0mYellow (255,255,0)\e[0m"
echo -e "\e[38;2;0;255;255mCyan (0,255,255)\e[0m"
echo -e "\e[38;2;255;0;255mMagenta (255,0,255)\e[0m"