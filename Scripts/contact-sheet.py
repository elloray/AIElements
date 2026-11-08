from pathlib import Path
from PIL import Image, ImageDraw
root = Path('.impeccable/review')
for scheme in ['light','dark']:
 for width in [350,640]:
  paths=sorted(root.glob(f'*-{scheme}-{width}.png'))
  canvas=Image.new('RGB',(1200,((len(paths)+2)//3)*300),'#e8e8e8' if scheme=='light' else '#303030')
  d=ImageDraw.Draw(canvas)
  for i,p in enumerate(paths):
   image=Image.open(p).convert('RGB');image.thumbnail((390,265))
   x=(i%3)*400;y=(i//3)*300
   d.text((x+10,y+5),p.name,fill='black' if scheme=='light' else 'white')
   canvas.paste(image,(x+5,y+28))
  canvas.save(root/f'contact-{scheme}-{width}.jpg')
