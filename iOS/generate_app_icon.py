#!/usr/bin/env python3
"""
Generate EpusdtPay App Icon - USDT Payment System
Creates a professional 1024x1024 app icon with USDT branding
"""

from PIL import Image, ImageDraw, ImageFont
import math
import os

SIZE = 1024

def create_icon():
    # Create base image with dark background
    img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # ===== Background gradient (dark blue-black) =====
    for y in range(SIZE):
        ratio = y / SIZE
        r = int(15 + ratio * 10)   # 15 -> 25
        g = int(18 + ratio * 12)   # 18 -> 30
        b = int(24 + ratio * 16)   # 24 -> 40
        draw.line([(0, y), (SIZE, y)], fill=(r, g, b, 255))

    # ===== Subtle radial glow in center =====
    center_x, center_y = SIZE // 2, SIZE // 2 - 30
    for radius in range(350, 0, -1):
        alpha = int(40 * (1 - radius / 350))
        # Gold glow
        r_color = int(212 * (1 - radius / 350 * 0.5))
        g_color = int(175 * (1 - radius / 350 * 0.5))
        b_color = int(55 * (1 - radius / 350 * 0.5))
        draw.ellipse(
            [center_x - radius, center_y - radius, center_x + radius, center_y + radius],
            fill=(r_color, g_color, b_color, alpha)
        )

    # ===== Draw USDT symbol (₮) =====
    # Main circle border (gold ring)
    ring_center = (SIZE // 2, SIZE // 2 - 20)
    ring_outer = 310
    ring_inner = 270
    ring_thickness = ring_outer - ring_inner

    # Draw gold ring
    for angle_deg in range(360):
        angle = math.radians(angle_deg)
        for r in range(ring_inner, ring_outer):
            x = int(ring_center[0] + r * math.cos(angle))
            y = int(ring_center[1] + r * math.sin(angle))
            if 0 <= x < SIZE and 0 <= y < SIZE:
                # Gradient gold effect
                brightness = 0.85 + 0.15 * math.sin(angle * 2 + math.pi / 4)
                gold_r = int(212 * brightness)
                gold_g = int(175 * brightness)
                gold_b = int(55 * brightness)
                alpha = 255 if ring_inner + 5 < r < ring_outer - 5 else 180
                img.putpixel((x, y), (gold_r, gold_g, gold_b, alpha))

    # ===== Draw "₮" symbol using drawing primitives =====
    symbol_cx = SIZE // 2
    symbol_cy = SIZE // 2 - 20

    # Horizontal bars (top of ₮)
    bar_width = 240
    bar_height = 32
    bar_y1 = symbol_cy - 140

    # First horizontal bar
    draw.rounded_rectangle(
        [symbol_cx - bar_width // 2, bar_y1, symbol_cx + bar_width // 2, bar_y1 + bar_height],
        radius=16,
        fill=(212, 175, 55, 255)
    )

    # Second horizontal bar (slightly below)
    bar_y2 = bar_y1 + bar_height + 14
    draw.rounded_rectangle(
        [symbol_cx - bar_width // 2, bar_y2, symbol_cx + bar_width // 2, bar_y2 + bar_height],
        radius=16,
        fill=(212, 175, 55, 255)
    )

    # Vertical bar (stem of ₮)
    stem_width = 44
    stem_top = bar_y2 + bar_height - 10
    stem_bottom = symbol_cy + 200
    draw.rounded_rectangle(
        [symbol_cx - stem_width // 2, stem_top, symbol_cx + stem_width // 2, stem_bottom],
        radius=12,
        fill=(212, 175, 55, 255)
    )

    # ===== Add "USDT" text at bottom =====
    try:
        # Try to use a system font
        font_paths = [
            "/System/Library/Fonts/SFCompact.ttf",
            "/System/Library/Fonts/Helvetica.ttc",
            "/System/Library/Fonts/HelveticaNeue.ttc",
            "/Library/Fonts/Arial.ttf",
            "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        ]
        font = None
        for fp in font_paths:
            if os.path.exists(fp):
                try:
                    font = ImageFont.truetype(fp, 72)
                    break
                except:
                    continue
        if font is None:
            font = ImageFont.load_default()
    except:
        font = ImageFont.load_default()

    text = "USDT"
    text_bbox = draw.textbbox((0, 0), text, font=font)
    text_width = text_bbox[2] - text_bbox[0]
    text_x = (SIZE - text_width) // 2
    text_y = SIZE - 180

    # Text shadow
    draw.text((text_x + 2, text_y + 2), text, fill=(0, 0, 0, 120), font=font)
    # Main text
    draw.text((text_x, text_y), text, fill=(212, 175, 55, 255), font=font)

    # ===== Add subtle decorative dots at corners =====
    dot_color = (212, 175, 55, 60)
    dot_positions = [
        (80, 80, 8), (SIZE - 80, 80, 8),
        (80, SIZE - 80, 8), (SIZE - 80, SIZE - 80, 8),
        (50, SIZE // 2, 5), (SIZE - 50, SIZE // 2, 5),
    ]
    for dx, dy, dr in dot_positions:
        draw.ellipse([dx - dr, dy - dr, dx + dr, dy + dr], fill=dot_color)

    # Convert to RGB (remove alpha for final icon)
    final = Image.new('RGB', (SIZE, SIZE), (15, 18, 24))
    final.paste(img, mask=img.split()[3])

    return final


def main():
    icon_dir = "/Users/macbook/jiamihuobi/EPUSDT/ios手机系统/EpusdtPay/EpusdtPay/EpusdtPay/Assets.xcassets/AppIcon.appiconset"

    # Generate main icon (1024x1024)
    print("🎨 生成 App 图标...")
    icon = create_icon()

    # Save 1024x1024 main icon
    icon_path = os.path.join(icon_dir, "AppIcon-1024.png")
    icon.save(icon_path, "PNG", quality=100)
    print(f"  ✅ 1024x1024 → {icon_path}")

    # Generate dark variant (slightly darker)
    dark_icon = icon.copy()
    from PIL import ImageEnhance
    enhancer = ImageEnhance.Brightness(dark_icon)
    dark_icon = enhancer.enhance(0.85)
    dark_path = os.path.join(icon_dir, "AppIcon-Dark-1024.png")
    dark_icon.save(dark_path, "PNG", quality=100)
    print(f"  ✅ 1024x1024 (Dark) → {dark_path}")

    # Generate tinted variant (more saturated gold)
    tinted_icon = icon.copy()
    enhancer = ImageEnhance.Color(tinted_icon)
    tinted_icon = enhancer.enhance(1.3)
    tinted_path = os.path.join(icon_dir, "AppIcon-Tinted-1024.png")
    tinted_icon.save(tinted_path, "PNG", quality=100)
    print(f"  ✅ 1024x1024 (Tinted) → {tinted_path}")

    # Update Contents.json to reference the icon files
    contents_json = '''{
  "images" : [
    {
      "filename" : "AppIcon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "AppIcon-Dark-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "tinted"
        }
      ],
      "filename" : "AppIcon-Tinted-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}'''

    contents_path = os.path.join(icon_dir, "Contents.json")
    with open(contents_path, 'w') as f:
        f.write(contents_json)
    print(f"  ✅ Contents.json 已更新")

    print("\n🎉 App 图标生成完成！")
    print("   设计风格: 深色背景 + 金色 ₮ 符号 + USDT 文字")
    print("   包含: 普通 / Dark / Tinted 三种变体")


if __name__ == "__main__":
    main()
