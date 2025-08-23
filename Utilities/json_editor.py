"""
Dynamic JSON Editor - Streamlit Application

A modular Streamlit app that automatically detects JSON file structures
and provides an intuitive interface for editing them.
"""

import streamlit as st
import json
import os
from pathlib import Path
from typing import Dict, Any, List, Union
import copy

class JSONEditor:
    """Main class for the dynamic JSON editor functionality."""
    
    def __init__(self, data_directory: str = None):
        """Initialize the JSON editor with a data directory."""
        self.data_directory = data_directory or self.get_default_data_directory()
        
    def get_default_data_directory(self) -> str:
        """Get the default data directory path."""
        # Default to the data folder in the new-game-project
        default_path = r"C:\Users\alexa\Documents\Coding\Smyte\new-game-project\data"
        if os.path.exists(default_path):
            return default_path
        # Fallback to current directory
        return os.getcwd()
    
    def get_json_files(self) -> List[str]:
        """Get all JSON files from the data directory."""
        if not os.path.exists(self.data_directory):
            return []
        
        json_files = []
        for file in os.listdir(self.data_directory):
            if file.endswith('.json'):
                json_files.append(file)
        return sorted(json_files)
    
    def load_json_file(self, filename: str) -> Dict[str, Any]:
        """Load a JSON file and return its contents."""
        file_path = os.path.join(self.data_directory, filename)
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception as e:
            st.error(f"Error loading {filename}: {str(e)}")
            return {}
    
    def save_json_file(self, filename: str, data: Dict[str, Any]) -> bool:
        """Save data to a JSON file."""
        file_path = os.path.join(self.data_directory, filename)
        try:
            with open(file_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
            return True
        except Exception as e:
            st.error(f"Error saving {filename}: {str(e)}")
            return False
    
    def render_json_editor(self, data: Dict[str, Any], key_prefix: str = "") -> Dict[str, Any]:
        """Recursively render form elements for JSON data editing."""
        edited_data = copy.deepcopy(data)
        
        for key, value in data.items():
            full_key = f"{key_prefix}_{key}" if key_prefix else key
            
            if isinstance(value, dict):
                st.subheader(f"📁 {key}")
                with st.expander(f"Edit {key}", expanded=True):
                    edited_data[key] = self.render_json_editor(value, full_key)
            
            elif isinstance(value, list):
                st.subheader(f"📋 {key}")
                edited_data[key] = self.render_list_editor(key, value, full_key)
            
            elif isinstance(value, bool):
                edited_data[key] = st.checkbox(
                    f"{key}",
                    value=value,
                    key=f"checkbox_{full_key}"
                )
            
            elif isinstance(value, (int, float)):
                if isinstance(value, int):
                    edited_data[key] = st.number_input(
                        f"{key}",
                        value=value,
                        key=f"number_{full_key}"
                    )
                else:
                    edited_data[key] = st.number_input(
                        f"{key}",
                        value=value,
                        format="%.4f",
                        key=f"float_{full_key}"
                    )
            
            elif isinstance(value, str):
                # Check if it's a long text (multiline)
                if len(value) > 100 or '\n' in value:
                    edited_data[key] = st.text_area(
                        f"{key}",
                        value=value,
                        height=100,
                        key=f"textarea_{full_key}"
                    )
                else:
                    edited_data[key] = st.text_input(
                        f"{key}",
                        value=value,
                        key=f"text_{full_key}"
                    )
            
            else:
                # For other types, show as text input with JSON string
                try:
                    json_str = json.dumps(value, indent=2)
                    new_json_str = st.text_area(
                        f"{key} (JSON)",
                        value=json_str,
                        height=100,
                        key=f"json_{full_key}"
                    )
                    edited_data[key] = json.loads(new_json_str)
                except:
                    st.error(f"Invalid JSON for {key}")
                    edited_data[key] = value
        
        return edited_data
    
    def render_list_editor(self, key: str, items: List[Any], full_key: str) -> List[Any]:
        """Render editor for list items."""
        edited_items = []
        
        with st.expander(f"Edit {key} (List with {len(items)} items)", expanded=True):
            # Add a number input to control list size
            current_size = len(items)
            new_size = st.number_input(
                f"Number of items in {key}",
                min_value=0,
                value=current_size,
                key=f"size_{full_key}"
            )
            
            # Adjust list size if changed
            if new_size != current_size:
                if new_size > current_size:
                    # Add new items
                    for i in range(current_size, new_size):
                        if items:
                            # Try to infer type from existing items
                            sample_item = items[0]
                            if isinstance(sample_item, dict):
                                new_item = {}
                            elif isinstance(sample_item, list):
                                new_item = []
                            elif isinstance(sample_item, bool):
                                new_item = False
                            elif isinstance(sample_item, int):
                                new_item = 0
                            elif isinstance(sample_item, float):
                                new_item = 0.0
                            else:
                                new_item = ""
                        else:
                            new_item = ""
                        items.append(new_item)
                else:
                    # Remove items from the end
                    items = items[:new_size]
            
            # Edit existing items
            for i in range(min(len(items), new_size)):
                if i < len(items):
                    item = items[i]
                else:
                    item = ""
                
                st.write(f"**Item {i + 1}:**")
                item_key = f"{full_key}_item_{i}"
                
                if isinstance(item, dict):
                    edited_item = self.render_json_editor(item, item_key)
                elif isinstance(item, list):
                    edited_item = self.render_list_editor(f"item_{i}", item, item_key)
                elif isinstance(item, bool):
                    edited_item = st.checkbox(
                        f"Value",
                        value=item,
                        key=f"list_bool_{item_key}"
                    )
                elif isinstance(item, (int, float)):
                    if isinstance(item, int):
                        edited_item = st.number_input(
                            f"Value",
                            value=item,
                            key=f"list_number_{item_key}"
                        )
                    else:
                        edited_item = st.number_input(
                            f"Value",
                            value=item,
                            format="%.4f",
                            key=f"list_float_{item_key}"
                        )
                elif isinstance(item, str):
                    if len(item) > 50:
                        edited_item = st.text_area(
                            f"Value",
                            value=item,
                            key=f"list_textarea_{item_key}"
                        )
                    else:
                        edited_item = st.text_input(
                            f"Value",
                            value=item,
                            key=f"list_text_{item_key}"
                        )
                else:
                    try:
                        json_str = json.dumps(item, indent=2)
                        new_json_str = st.text_area(
                            f"Value (JSON)",
                            value=json_str,
                            key=f"list_json_{item_key}"
                        )
                        edited_item = json.loads(new_json_str)
                    except:
                        st.error(f"Invalid JSON for item {i + 1}")
                        edited_item = item
                
                edited_items.append(edited_item)
                st.divider()
        
        return edited_items


def main():
    """Main Streamlit application."""
    st.set_page_config(
        page_title="Dynamic JSON Editor",
        page_icon="📝",
        layout="wide"
    )
    
    st.title("📝 Dynamic JSON Editor")
    st.markdown("---")
    
    # Initialize the editor
    editor = JSONEditor()
    
    # Sidebar for configuration
    with st.sidebar:
        st.header("⚙️ Configuration")
        
        # Data directory input
        custom_directory = st.text_input(
            "Data Directory Path",
            value=editor.data_directory,
            help="Path to the directory containing JSON files"
        )
        
        if custom_directory != editor.data_directory:
            editor.data_directory = custom_directory
        
        # Check if directory exists
        if not os.path.exists(editor.data_directory):
            st.error(f"Directory does not exist: {editor.data_directory}")
            st.stop()
        
        st.success(f"✅ Directory: {editor.data_directory}")
        
        # File selection
        json_files = editor.get_json_files()
        
        if not json_files:
            st.warning("No JSON files found in the directory.")
            st.stop()
        
        selected_file = st.selectbox(
            "Select JSON File",
            json_files,
            help="Choose a JSON file to edit"
        )
        
        # File info
        if selected_file:
            file_path = os.path.join(editor.data_directory, selected_file)
            file_size = os.path.getsize(file_path)
            st.info(f"📄 File: {selected_file}\n📏 Size: {file_size} bytes")
    
    # Main editing area
    if selected_file:
        st.header(f"Editing: {selected_file}")
        
        # Load the JSON data
        json_data = editor.load_json_file(selected_file)
        
        if not json_data:
            st.error("Failed to load JSON data or file is empty.")
            st.stop()
        
        # Create tabs for different views
        tab1, tab2, tab3 = st.tabs(["🖊️ Edit", "👀 Preview", "📋 Raw JSON"])
        
        with tab1:
            st.subheader("Edit JSON Data")
            
            # Render the editor without form (we'll handle state management differently)
            edited_data = editor.render_json_editor(json_data)
            
            # Action buttons outside of form
            st.markdown("---")
            col1, col2, col3 = st.columns([1, 1, 1])
            
            with col1:
                if st.button("💾 Save Changes", type="primary", key="save_btn"):
                    if editor.save_json_file(selected_file, edited_data):
                        st.success(f"✅ Successfully saved {selected_file}")
                        st.rerun()
                    else:
                        st.error(f"❌ Failed to save {selected_file}")
            
            with col2:
                if st.button("🔄 Reset", key="reset_btn"):
                    st.rerun()
            
            with col3:
                # Create download link
                json_str = json.dumps(edited_data, indent=2, ensure_ascii=False)
                st.download_button(
                    label="📥 Download Copy",
                    data=json_str,
                    file_name=f"copy_{selected_file}",
                    mime="application/json",
                    key="download_btn"
                )
        
        with tab2:
            st.subheader("Preview Current Data")
            if 'edited_data' in locals():
                st.json(edited_data)
            else:
                st.json(json_data)
        
        with tab3:
            st.subheader("Raw JSON")
            if 'edited_data' in locals():
                json_str = json.dumps(edited_data, indent=2, ensure_ascii=False)
            else:
                json_str = json.dumps(json_data, indent=2, ensure_ascii=False)
            
            st.code(json_str, language="json")
    
    # Footer
    st.markdown("---")
    st.markdown(
        "💡 **Tip**: This editor automatically adapts to any JSON structure. "
        "Add new JSON files to your data directory and they'll appear in the file selector!"
    )


if __name__ == "__main__":
    main()
