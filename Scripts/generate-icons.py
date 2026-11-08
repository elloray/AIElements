"""Generate native vector paths from pinned Lucide SVGs (ISC license)."""
import urllib.request,json,tarfile,io,pathlib,xml.etree.ElementTree as ET
from fontTools.pens.recordingPen import RecordingPen
from fontTools.svgLib import SVGPath
names='terminal circle-check circle circle-dot circle-x circle-alert chevron-right chevron-down arrow-up arrow-down arrow-up-right plus x copy check rotate-ccw thumbs-up thumbs-down globe search file file-text file-code folder folder-open route list-todo list-checks loader-circle bot paperclip square flask-conical ellipsis sun moon circle-dashed pencil wrap-text layers message-circle-dashed rotate-cw'.split()
meta=json.load(urllib.request.urlopen('https://registry.npmjs.org/lucide-static/0.468.0'))
t=tarfile.open(fileobj=io.BytesIO(urllib.request.urlopen(meta['dist']['tarball']).read()),mode='r:gz')
def case(n):
 parts=n.split('-');return parts[0]+''.join(x.title() for x in parts[1:])
def point(p):return f'CGPoint(x: {p[0]:.6f}, y: {p[1]:.6f})'
s='import SwiftUI\n\n/// Lucide icons rendered as native vector paths, never SF Symbol approximations.\npublic enum AIIconName: String, CaseIterable, Sendable {\n'
s+=''.join(f'    case {case(n)} = "{n}"\n' for n in names)+'}\n'
s+='''public struct AIIcon: View {
    public var name: AIIconName
    public var size: CGFloat
    public init(_ name: AIIconName, size: CGFloat = 16) { self.name = name; self.size = size }
    public var body: some View {
        IconShape(name: name).stroke(style: StrokeStyle(lineWidth: size / 12, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size).accessibilityHidden(true)
    }
}
private struct IconShape: Shape {
    var name: AIIconName
    func path(in rect: CGRect) -> Path {
        var p = Path()
        switch name {
'''
for n in names:
 data=t.extractfile(f'package/icons/{n}.svg').read()
 pen=RecordingPen();SVGPath.fromstring(data).draw(pen)
 s+=f'        case .{case(n)}:\n'
 for op,args in pen.value:
  if op=='moveTo':s+=f'            p.move(to: {point(args[0])})\n'
  elif op=='lineTo':s+=f'            p.addLine(to: {point(args[0])})\n'
  elif op=='curveTo':s+=f'            p.addCurve(to: {point(args[2])}, control1: {point(args[0])}, control2: {point(args[1])})\n'
  elif op=='qCurveTo':s+=f'            p.addQuadCurve(to: {point(args[1])}, control: {point(args[0])})\n'
  elif op=='closePath':s+='            p.closeSubpath()\n'
  elif op!='endPath':raise ValueError(op)
s+='''        }
        return p.applying(CGAffineTransform(scaleX: rect.width / 24, y: rect.height / 24))
    }
}
'''
pathlib.Path('Sources/AIElements/Icons.swift').write_text(s)
for m in t.getmembers():
 if m.name.lower().endswith('license'):pathlib.Path('Sources/AIElements/Resources/Lucide-LICENSE').write_bytes(t.extractfile(m).read())
print('Generated',len(names),'icons')
