from PIL import Image, ImageDraw
import os

SIZE = 1024
image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(image)

# Rounded blue app tile with a subtle vertical gradient.
for y in range(SIZE):
    t = y / (SIZE - 1)
    color = (int(16 + 10*t), int(105 + 60*t), int(218 + 15*t), 255)
    draw.line((0, y, SIZE, y), fill=color)
mask = Image.new("L", (SIZE, SIZE), 0)
ImageDraw.Draw(mask).rounded_rectangle((24, 24, SIZE-24, SIZE-24), radius=210, fill=255)
image.putalpha(mask)
draw = ImageDraw.Draw(image)

# Clipboard: white outline, top clip and checklist lines.
draw.rounded_rectangle((250, 190, 670, 750), radius=52, outline="white", width=44)
draw.rounded_rectangle((390, 135, 530, 235), radius=34, fill="white")
draw.rounded_rectangle((425, 170, 495, 205), radius=14, fill=(25, 125, 225, 255))

# Checklist ticks and writing lines.
for y in (340, 475, 610):
    draw.line((330, y+30, 365, y+65, 425, y-10), fill="white", width=28, joint="curve")
    draw.rounded_rectangle((465, y, 600, y+26), radius=13, fill="white")

# Amber package with white check mark badge.
draw.rounded_rectangle((560, 565, 850, 845), radius=45, fill=(255, 174, 35, 255), outline="white", width=18)
draw.line((560, 650, 705, 720, 850, 650), fill=(255, 238, 195, 255), width=18)
draw.line((705, 720, 705, 830), fill=(255, 238, 195, 255), width=18)
draw.ellipse((700, 735, 925, 960), fill="white")
draw.line((755, 845, 800, 890, 875, 805), fill=(20, 125, 210, 255), width=30, joint="curve")

os.makedirs("assets", exist_ok=True)
image.convert("RGB").save("assets/app_icon.png", quality=95)
print("Generated assets/app_icon.png")
