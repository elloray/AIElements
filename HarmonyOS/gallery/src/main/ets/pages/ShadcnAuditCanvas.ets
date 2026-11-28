import { AIColors, AIShadcnExample, AIShadcnView, loadAIShadcnCatalog, registerAIElementsFonts } from '@aielements/arkui';

// The SDK Previewer captures this page at 360 vp. The strip identifies the component
// after the engine has laid it out and is removed from every exported image.
@Component
export struct ShadcnAuditCanvas {
  @State private index: number = 0;
  private samples: AIShadcnExample[] = loadAIShadcnCatalog();
  private timer: number = -1;

  aboutToAppear(): void {
    registerAIElementsFonts();
    this.timer = setInterval(() => {
      this.index = (this.index + 1) % this.samples.length;
    }, 850);
  }

  aboutToDisappear(): void { clearInterval(this.timer); }

  build() {
    Column() {
      ForEach([this.index], (i: number) => {
        Stack() {
          AIShadcnView({ node: this.samples[i].root, animationsActive: false })
        }.width('100%').constraintSize({ minHeight: 64 })
      }, (i: number) => String(i))
      Row() {
        Rect().width(16).height(8).fill('#ff00ff')
        ForEach([1, 2, 4, 8, 16, 32, 64], (bit: number) => {
          Rect().width(16).height(8).fill((this.index & bit) !== 0 ? '#ffffff' : '#000000')
        }, (bit: number) => String(bit))
        Rect().width(16).height(8).fill('#00ff00')
      }.width('100%')
    }.width('100%').height('100%').backgroundColor(AIColors.background)
  }
}
