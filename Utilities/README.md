# Dynamic JSON Editor

A powerful Streamlit application that provides an intuitive interface for editing JSON files. The app automatically detects JSON file structures and creates dynamic forms for easy editing.

## Features

- 🔄 **Dynamic Structure Detection**: Automatically adapts to any JSON format
- 📝 **Intuitive Editing**: Smart form elements based on data types
- 📁 **Multiple File Support**: Edit multiple JSON files from a directory
- 🎯 **Modular Design**: Easily handles nested objects and arrays
- 💾 **Safe Editing**: Preview changes before saving
- 📤 **Export Options**: Download edited copies of your files

## Installation

1. Make sure you have Python 3.7+ installed
2. Install the required dependencies:
   ```bash
   pip install -r requirements.txt
   ```

## Usage

### Quick Start

1. Run the Streamlit app:
   ```bash
   streamlit run json_editor.py
   ```

2. The app will automatically try to load JSON files from:
   - `C:\Users\alexa\Documents\Coding\Smyte\new-game-project\data` (default)
   - Or you can specify a custom directory path in the sidebar

3. Select a JSON file from the dropdown menu

4. Edit the data using the automatically generated form elements

5. Preview your changes and save when ready

### Features Explained

#### Automatic Type Detection
The app automatically creates appropriate input elements based on your data types:
- **Strings**: Text input (single line) or text area (multi-line)
- **Numbers**: Number input with appropriate formatting
- **Booleans**: Checkboxes
- **Objects**: Nested expandable sections
- **Arrays**: List editors with add/remove functionality

#### Smart Form Generation
- Nested objects become collapsible sections
- Arrays get individual item editors
- Long text automatically becomes text areas
- Complex data gets JSON editors

#### File Management
- Browse JSON files from any directory
- Real-time file information (size, path)
- Safe saving with error handling
- Export copies without overwriting originals

## Project Structure

```
json_editor.py          # Main Streamlit application
requirements.txt        # Python dependencies
README.md              # This file
.github/
  copilot-instructions.md  # Development guidelines
```

## Customization

The app is designed to be modular and easily extensible:

### Adding New Data Types
Modify the `render_json_editor` method in the `JSONEditor` class to handle new data types.

### Custom Validation
Add validation logic in the form submission handlers.

### UI Customization
Modify the Streamlit components and styling as needed.

## Tips

- Use the **Preview** tab to see your changes before saving
- The **Raw JSON** tab shows the exact JSON structure
- Large text fields automatically become text areas
- List items can be added, edited, or removed individually
- The app remembers your directory preference

## Troubleshooting

### Common Issues

1. **"No JSON files found"**: Make sure your directory path is correct and contains .json files
2. **"Directory does not exist"**: Check that the path exists and is accessible
3. **JSON parsing errors**: Ensure your JSON files are valid

### Getting Help

If you encounter issues:
1. Check the error messages in the Streamlit interface
2. Verify your JSON files are valid using a JSON validator
3. Make sure the directory path is correct

## Development

This project uses:
- **Streamlit**: For the web interface
- **Python Standard Library**: For JSON handling and file operations
- **Type Hints**: For better code documentation and IDE support

The app is designed to be self-contained with minimal dependencies for easy deployment and customization.
