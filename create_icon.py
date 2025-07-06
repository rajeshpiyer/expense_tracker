#!/usr/bin/env python3
"""
FinanceFlow App Icon Generator
Creates a simple app icon using Python PIL (Pillow)
"""

try:
    from PIL import Image, ImageDraw, ImageFont
    import os
except ImportError:
    print("PIL (Pillow) not installed. Install with: pip install Pillow")
    exit(1)

def create_financeflow_icon():
    """Create a simple FinanceFlow app icon"""
    
    # Icon size
    size = 1024
    
    # Colors
    bg_color = "#1A1A1A"  # Dark grey
    accent_color = "#FFD700"  # Professional yellow
    
    # Create image with dark background
    img = Image.new('RGBA', (size, size), bg_color)
    draw = ImageDraw.Draw(img)
    
    # Draw circular background with gradient effect
    center = size // 2
    radius = size // 2 - 50
    
    # Draw main circle
    draw.ellipse([center - radius, center - radius, center + radius, center + radius], 
                 fill=bg_color, outline=accent_color, width=8)
    
    # Draw "F" letter in the center
    try:
        # Try to use a system font
        font_size = size // 3
        font = ImageFont.truetype("arial.ttf", font_size)
    except:
        # Fallback to default font
        font = ImageFont.load_default()
    
    # Draw the "F" character
    text = "F"
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    
    text_x = (size - text_width) // 2
    text_y = (size - text_height) // 2 - 20
    
    draw.text((text_x, text_y), text, fill=accent_color, font=font)
    
    # Add some flow lines around the F
    for i in range(3):
        y_offset = center + (i - 1) * 80
        draw.line([center - 150, y_offset, center + 150, y_offset], 
                 fill=accent_color, width=4)
    
    # Save the icon
    output_path = "assets/images/app_icon.png"
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    img.save(output_path, "PNG")
    print(f"Icon created: {output_path}")
    
    return output_path

if __name__ == "__main__":
    create_financeflow_icon()
    print("\nNext steps:")
    print("1. Update pubspec.yaml to uncomment flutter_launcher_icons section")
    print("2. Run: flutter pub run flutter_launcher_icons")
    print("3. Run: flutter build apk --debug")
    print("4. Install the new APK on your device")
