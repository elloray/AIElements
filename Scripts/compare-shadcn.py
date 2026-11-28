"""Build same-scale comparisons from upstream browser and independent native captures."""
import argparse
import io
import json
from pathlib import Path
from statistics import mean

from PIL import Image, ImageChops, ImageCms, ImageDraw, ImageFont, ImageStat

repo = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--input", type=Path, default=repo / ".build/shadcn-audit")
parser.add_argument("--output", type=Path, default=repo / "Documentation/Images/Shadcn")
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)
samples = json.loads((repo / "Sources/AIElementsCatalog/Resources/shadcn-catalog.json").read_text())
platforms = [("web", "shadcn/ui"), ("mac", "macOS"), ("ios", "iPhone"), ("ipad", "iPad"), ("android", "Android"), ("harmony", "HarmonyOS Previewer")]
width = 360
font = ImageFont.load_default(size=14)
title = ImageFont.load_default(size=21)
records = []

def load(slug, theme, platform):
    prefix = "ios-" if platform in {"ios", "ipad"} else "mac-" if platform == "mac" else ""
    source = args.input / platform / (prefix + slug + "-" + theme + ".png")
    with Image.open(source) as raw:
        image = raw.convert("RGB")
        profile = raw.info.get("icc_profile")
        if profile:
            image = ImageCms.profileToProfile(image, ImageCms.ImageCmsProfile(io.BytesIO(profile)), ImageCms.createProfile("sRGB"))
        if image.width != width:
            image = image.resize((width,round(image.height*width/image.width)), Image.Resampling.LANCZOS)
        return image

def align(image, height, theme):
    canvas = Image.new("RGB",(width,height), "#0a0a0a" if theme == "dark" else "#ffffff")
    canvas.paste(image,(0,(height-image.height)//2))
    return canvas

def ink(image, theme):
    # Union of pixels sufficiently different from the sample background. This avoids
    # a high score caused just by large identical empty margins.
    background=Image.new("RGB",image.size,"#0a0a0a" if theme=="dark" else "#ffffff")
    diff=ImageChops.difference(image,background)
    channels=diff.split()
    return ImageChops.lighter(ImageChops.lighter(channels[0],channels[1]),channels[2]).point(lambda x:255 if x>=6 else 0)

# Detect a Previewer or simulator retaining the default palette across both runs.
for host,_ in platforms:
    light = load("button","light",host).getpixel((3,3))
    dark = load("button","dark",host).getpixel((3,3))
    if min(light)<192 or max(dark)>64:
        raise RuntimeError(f"{host} returned an unexpected canvas color: light={light}, dark={dark}")

for sample in samples:
    slug = sample["id"]
    sheets=[]
    for theme in ("light","dark"):
        images=[load(slug,theme,host) for host,_ in platforms]
        height=max(im.height for im in images)
        aligned=[align(im,height,theme) for im in images]
        sheet=Image.new("RGB",(len(platforms)*(width+2)-2,height+28),"#e1e2e5")
        draw=ImageDraw.Draw(sheet)
        refmask=ink(aligned[0],theme)
        for i,((host,label),im) in enumerate(zip(platforms,aligned)):
            x=i*(width+2)
            draw.text((x+8,4),f"{label}   /   {images[i].height} {('px' if host=='web' else 'pt' if host in ('mac','ios','ipad') else 'vp' if host=='harmony' else 'dp')}",font=font,fill="#24262a")
            sheet.paste(im,(x,28))
            hostmask=ink(im,theme)
            if hostmask.getbbox() is None or len(images[i].getcolors(1) or [])==1:
                raise RuntimeError(f"Empty capture: {slug}/{theme}/{host}")
            mask=ImageChops.lighter(refmask,hostmask)
            delta=ImageStat.Stat(ImageChops.difference(aligned[0],im),mask=mask)
            records.append(dict(component=slug,appearance=theme,platform=host,height=images[i].height,
                                foregroundMeanAbsoluteRGB=round(mean(delta.mean),2)))
        sheets.append(sheet)
    total=Image.new("RGB",(sheets[0].width,40+sum(im.height for im in sheets)+6),"#e1e2e5")
    ImageDraw.Draw(total).text((8,6),sample["title"]+"  /  Light + Dark",font=title,fill="#101114")
    y=40
    for im in sheets:
        total.paste(im,(0,y))
        y+=im.height+6
    total.save(args.output/(slug+".webp"),lossless=True,method=4)
(args.output/"measurements.json").write_text(json.dumps(records,indent=2)+"\n")
lines=["# shadcn/ui 组件截图索引","","每张图从左到右依次为官网、macOS、iPhone、iPad、Android 和 HarmonyOS SDK Previewer。上排为浅色，下排为深色。所有列均以 360 个逻辑单位宽度显示。","","[查看取样和校验方法](../../Shadcn-Components.md) · [逐平台测量数据](measurements.json)","","| 组件 | 组件 | 组件 |","| --- | --- | --- |"]
def reference(item):
    return item.get("selector") or ("https://ui.shadcn.com/docs/components/base/" + item["id"] +
                                    ("#" + item["section"] if item.get("section") else ""))

links=[f"[{item['title']}]({item['id']}.webp) · [官网]({reference(item)})" for item in samples]
for i in range(0,len(links),3):
    lines.append("| "+" | ".join((links[i:i+3] + [""]*3)[:3])+" |")
(args.output/"README.md").write_text("\n".join(lines)+"\n")
print(f"{len(samples)} sheets, {len(records)} measurements")
