# Story Background Management System

## Overview

The story background management system lets each map have its own story background, and lets users add extra social rules through the GodUI. Both the story background and the social rules are ultimately integrated into the AI dialog prompts.

## File Structure

```
script/ai/background_story/
├── BackgroundStoryManager.gd    # Core manager class
├── BackgroundStoryUI.gd         # UI component class (optional)
└── README.md                    # This document
```

## Core Features

### 1. Preset Story Backgrounds

The system comes with story backgrounds for three maps:
- **Office**: a modern corporate office environment
- **School**: an educational institution environment
- **Jail**: a prison management environment

Each background includes:
- Map name
- Organization name
- Background description (organization, environment, time period, cultural context, economic situation)
- Preset social rules

### 2. Custom Social Rules

Users can add, remove, and clear custom social rules through the GodUI. These rules are applied to AI dialog together with the preset rules.

## API

### BackgroundStoryManager Static Methods

#### Basic Operations

```gdscript
# Initialize the manager (defaults to the Office background)
BackgroundStoryManager.initialize(map_name: String = "Office")

# Set the current story background (falls back to Office for unknown maps)
BackgroundStoryManager.set_background(map_name: String)

# Get the list of available maps
BackgroundStoryManager.get_available_maps() -> Array[String]

# Check whether a map has a background config
BackgroundStoryManager.is_map_available(map_name: String) -> bool
```

#### Current State

```gdscript
# Get the current map name
BackgroundStoryManager.get_current_map_name() -> String

# Get the current organization name
BackgroundStoryManager.get_current_company_name() -> String

# Get the current background description
BackgroundStoryManager.get_current_background_description() -> String
```

#### Rule Management

```gdscript
# Get preset rules
BackgroundStoryManager.get_preset_rules() -> Array[String]

# Get custom rules
BackgroundStoryManager.get_custom_rules() -> Array[String]

# Get all rules (preset + custom)
BackgroundStoryManager.get_all_rules() -> Array[String]

# Add a custom rule (returns false for an empty rule)
BackgroundStoryManager.add_custom_rule(rule: String)

# Remove a custom rule (returns false for an invalid index)
BackgroundStoryManager.remove_custom_rule(index: int)

# Clear all custom rules
BackgroundStoryManager.clear_custom_rules()
```

#### Prompt Generation

```gdscript
# Generate the full background and rules prompt
BackgroundStoryManager.generate_background_prompt() -> String

# Get the background info section used in prompts
BackgroundStoryManager.get_background_info_for_prompt() -> String

# Get summary info about the background
BackgroundStoryManager.get_background_summary() -> Dictionary
```

#### Data Persistence

```gdscript
# Save custom rules to user://custom_social_rules.json
BackgroundStoryManager.save_custom_rules()

# Load custom rules from user://custom_social_rules.json
BackgroundStoryManager.load_custom_rules()
```

## Usage Examples

### 1. Setting the background when a map is selected

```gdscript
# In MapSelection.gd
func _on_office_selected():
    # Set the office story background
    BackgroundStoryManager.set_background("Office")
    # Load the scene
    get_tree().change_scene_to_file("res://scene/maps/Office.tscn")
```

### 2. Using the background in AI dialog

```gdscript
# In ConversationManager.gd
func build_dialog_prompt(...):
    # Get the story background and social rules
    var background_prompt = BackgroundStoryManager.generate_background_prompt()
    
    var prompt = "You are an employee..."
    
    # Add the story background and social rules
    if not background_prompt.is_empty():
        prompt += "\n\n" + background_prompt
    
    # Continue building the rest of the prompt...
```

### 3. Managing rules in the UI

```gdscript
# In GodUI.gd
func _on_background_pressed():
    background_popup.popup_centered()
    _init_background_popup()

func _on_add_rule_pressed():
    var rule_text = add_rule_input.text.strip_edges()
    if BackgroundStoryManager.add_custom_rule(rule_text):
        add_rule_input.text = ""
        _update_custom_rules_display()
```

## Data Structures

### StoryBackground class

```gdscript
class StoryBackground:
    var map_name: String                 # Map name
    var company_name: String             # Organization name
    var background_description: String   # Background description
    var preset_rules: Array[String]      # List of preset rules
```

### SocialRule class

```gdscript
class SocialRule:
    var rule_text: String        # Rule text
    var is_custom: bool          # Whether this is a custom rule
```

## Preset Configurations

### Office
- **Organization**: CountSheep Game Company
- **Background**: A modern office environment that values efficiency and teamwork
- **Preset rules**: Professional conduct during working hours, meeting room booking, keeping work areas tidy, etc.

### School
- **Organization**: Sunshine Academy
- **Background**: An educational institution with harmonious teacher-student relationships
- **Preset rules**: Classroom discipline, respect for teachers and classmates, study habits, etc.

### Jail
- **Organization**: New Hope Prison
- **Background**: A strictly managed prison environment focused on rehabilitation
- **Preset rules**: Prison discipline, safety regulations, codes of conduct, etc.

## Extension Guide

### Adding a new map background

1. Add a new entry to the `BACKGROUND_CONFIGS` dictionary in `BackgroundStoryManager.gd`:

```gdscript
static var BACKGROUND_CONFIGS = {
    # ...existing maps...
    "NewMap": {
        "company_name": "New Organization Name",
        "company_description": "A description of the organization...",
        "environment_description": "A description of the environment...",
        "time_period": "Modern day (2024)",
        "cultural_context": "The cultural context...",
        "economic_situation": "The economic situation...",
        "social_rules": [
            "Rule 1",
            "Rule 2",
            "Rule 3"
        ]
    }
}
```

2. Call `BackgroundStoryManager.set_background("NewMap")` from the map selection screen

### Custom UI components

You can use `BackgroundStoryUI.gd` as a reference to build your own story background management UI.

## Notes

1. **Static access**: All methods are static and can be called from anywhere
2. **Data persistence**: Custom rules are saved to `user://custom_social_rules.json` automatically whenever they are added, removed, or cleared, and are reloaded when a background is set
3. **Performance**: Prompts are generated on the fly, so be mindful of performance if they are generated very frequently
4. **Error handling**: Methods include basic error checks and sensible defaults

## Changelog

- **v1.0**: Initial version with basic story background and social rule management
- Preset backgrounds for three maps (Office, School, Jail)
- Add, remove, and clear custom social rules
- Integrated into AI dialog prompt generation
- Full GodUI support
