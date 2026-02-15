import glob
import os
from datetime import datetime


def merge_bits(output, input):
    for y in range(12):
        for x in range(14):
            if input[y][x] == "@":
                t = output[y]
                t = t[:x] + "@" + t[x+1:] 
                output[y] = t


def clear_mask(mask, image, shiftx, shitfy):
    for y in range(12):
        yi = y + shitfy
        if yi < 0:
            continue
        if yi >= 12:
            continue
        for x in range(14):
            xi = x + shiftx
            if xi < 0:
                continue
            if xi >= 14:
                continue
            if image[yi][xi] == "@":
                t = mask[y]
                t = t[:x] + "." + t[x+1:] 
                mask[y] = t


def gen_byte(s, hb):
    d = hb
    b = 1
    for c in s:
        if c == "@":
            d |= b
        b *= 2
    return f"{d:02X}"


def gen_hex(shift, line, mask=False):
    highbit = 0x80
    pad = '@'
    if not mask:
        pad = '.'
        if line[-1:] != "1":
            highbit = 0x00
            
    scan = pad*shift + line[:-1] + pad*(7-shift)
    s = "hex   "
    s += gen_byte(scan[0:7], highbit)
    s += gen_byte(scan[7:14], highbit)
    s += gen_byte(scan[14:21], highbit)
    s += "    ; " + scan
    return s


def gen_file(name):
    sprites = {}

    pad = "         "
    s = "* Sprite conversion to hex tables\n"
    s += f"* Date: {datetime.now().isoformat()}\n\n"

    out_idx = 0
    sprite_num = 0
    sprite_shift = 0
    image = []
    in_image = False
    with open(name,"r") as fp:
        for line in fp:
            line = line.replace("\n", "")
            if len(line) < 3:
                continue
            if line.startswith("#"):
                continue
            elif line.startswith("sprite:"):
                sprite_num = int(line[7:])
                continue
            elif line.startswith("shift:"):
                sprite_shift = int(line[6:])
                continue
            elif line.startswith("filenum:"):
                out_idx = int(line[8:])
                continue
            elif line.startswith("12481241248124"):
                in_image = not in_image
                if in_image:
                    # if starting an image, add an empty scanline
                    image.append("..............0")
                else:
                    # if image is done, add an empty scanline and save it
                    image.append("..............0")
                    if sprite_num not in sprites:
                        sprites[sprite_num] = {}
                    sprites[sprite_num][sprite_shift] = image
                    image=[]
            elif in_image:
                image.append(line)

    for sprite_num in range(len(sprites)):
        s += f"{pad}ds   \\\n"
        s += f"* Sprite# {sprite_num}\n"
        for sprite_shift in range(len(sprites[sprite_num])):
            s += f"* Shift# {sprite_shift}\n"
            for line in sprites[sprite_num][sprite_shift]:
                s += f"{pad}{gen_hex(sprite_shift,line)}\n"
        s += "         ds 4\n"  # sprite is 252 bytes pad to page
        # generate mask images for this sprite
        # 'or' all the shift images together
        # fill the mask with 1's
        # 9 shifts - [-1,0,1] 
        #    walk the shifted, 'or'ed input image clearing mask bits
        # use the resulting mask, shifted for [0-6]
        merged = []
        mask = []
        for i in range(12):
            merged.append("."*14+"1")
            mask.append("@"*14+"1")
        for sprite_shift in range(len(sprites[sprite_num])):
            merge_bits(merged, sprites[sprite_num][sprite_shift])
        clear_mask(mask, merged, -1, -1)
        clear_mask(mask, merged, -1,  0)
        clear_mask(mask, merged, -1,  1)
        clear_mask(mask, merged,  0, -1)
        clear_mask(mask, merged,  0,  0)
        clear_mask(mask, merged,  0,  1)
        clear_mask(mask, merged,  1, -1)
        clear_mask(mask, merged,  1,  0)
        clear_mask(mask, merged,  1,  1)
        s += f"* Sprite mask# {sprite_num}\n"
        for sprite_shift in range(len(sprites[sprite_num])):
            s += f"* Shift mask# {sprite_shift}\n"
            for line in mask:
                s += f"{pad}{gen_hex(sprite_shift,line,mask=True)}\n"
        s += "         ds 4\n" # sprite is 252 bytes pad to page
    
    n = chr(out_idx+ord('A'))
    out_name = f"SPRITES_{n}.S"
    prefix  =  "        org    $8000\n"
    prefix += f"        dsk    ../bin/SPACEPARA.{n}#068000\n"
    prefix +=  "        typ    $06\n\n"
    s = prefix + s
    with open(os.path.join("src", out_name), "w") as fp:
        fp.write(s)


# Each sprites_*.txt file generates a different src/SPRITES_{x}.S 
# and assembles into SPACEPARA.{x}
for name in glob.glob(os.path.join("utilities", "sprites*.txt")):
    gen_file(name)
    