"""Generate BIS app icon: 'BIS' text in Rowsky font, primary purple on black."""
from PIL import Image, ImageDraw, ImageFont
import os

FONT_PATH = r"C:\Users\pedro.santos_idw\Projects\bis_flutter\assets\fonts\Rowsky-Demo.otf"
OUTPUT_DIR = r"C:\Users\pedro.santos_idw\Projects\bis_flutter"
PRIMARY_COLOR = (0xBB, 0x86, 0xFC)  # #BB86FC
BG_COLOR = (0, 0, 0)  # black

sizes = [256, 128, 64, 48, 32, 16]

def make_icon_image(size):
    img = Image.new("RGBA", (size, size), (*BG_COLOR, 255))
    draw = ImageDraw.Draw(img)
    
    # Use a font size that fills about 55% of the icon height for nice proportions
    font_size = int(size * 0.42)
    try:
        font = ImageFont.truetype(FONT_PATH, font_size)
    except Exception:
        font = ImageFont.load_default()

    text = "BIS"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    
    # Center the text
    x = (size - tw) / 2 - bbox[0]
    y = (size - th) / 2 - bbox[1]
    
    draw.text((x, y), text, fill=(*PRIMARY_COLOR, 255), font=font)
    return img

# Generate all sizes
images = [make_icon_image(s) for s in sizes]

# Save as ICO (Windows app icon)
ico_path = os.path.join(OUTPUT_DIR, "windows", "runner", "resources", "app_icon.ico")
images[0].save(ico_path, format="ICO", sizes=[(s, s) for s in sizes], append_images=images[1:])
print(f"Saved ICO: {ico_path}")

# Also save a 1024px PNG for reference
png = make_icon_image(1024)
png_path = os.path.join(OUTPUT_DIR, "app_icon.png")
png.save(png_path)
print(f"Saved PNG: {png_path}")
