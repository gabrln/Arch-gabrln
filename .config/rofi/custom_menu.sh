#!/bin/bash

# Rofi custom menu script using YAML and yq
# Improved mouse interaction and Nerd Font support
YAML_FILE="$HOME/.config/rofi/menu.yaml"
THEME="$HOME/.config/rofi/noctalia.rasi"

# Common rofi flags for better mouse experience
# Using a Bash array to handle arguments with spaces properly
ROFI_FLAGS=(
    -dmenu 
    -i 
    -hover-select 
    -me-select-entry "MouseSecondary" 
    -me-accept-entry "MousePrimary"
)

# Main loop to allow returning from submenus
while true; do
    # Get main menu categories
    categories=$(yq -r '.menu[].name' "$YAML_FILE")
    selected_category=$(echo -e "$categories" | rofi "${ROFI_FLAGS[@]}" -p "Menu" -theme "$THEME")

    # If Esc is pressed in main menu, exit script
    if [ -z "$selected_category" ]; then
        exit 0
    fi

    # Submenu loop
    while true; do
        # Get items for the selected category
        items=$(yq -r ".menu[] | select(.name == \"$selected_category\") | .items[].name" "$YAML_FILE")
        selected_item=$(echo -e "$items" | rofi "${ROFI_FLAGS[@]}" -p "$selected_category" -theme "$THEME")
        
        # If Esc is pressed in submenu, break to return to main menu
        if [ -z "$selected_item" ]; then
            break
        fi

        # Execute the command for the selected item and exit script
        cmd=$(yq -r ".menu[] | select(.name == \"$selected_category\") | .items[] | select(.name == \"$selected_item\") | .exec" "$YAML_FILE")
        eval "$cmd &"
        exit 0
    done
done
