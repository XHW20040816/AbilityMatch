import { Style3D } from '../common/Style3D';

/**
 * 3D 立体卡片：底部厚度底座 + 顶部渐变面板。
 * 手指按下时面板下沉贴住底座，松开回弹，形成实体按键手感。
 */
@Component
export struct Card3D {
  faceColors: string[] = Style3D.whiteFace;
  depthColor: string = Style3D.whiteDepth;
  radius: number = 22;
  depth: number = 6;
  facePadding: number = 16;
  faceBorderColor: string = '#33FFFFFF';
  shadowColor: string = Style3D.shadowSoft;
  shadowRadius: number = 18;
  action: () => void = () => {};
  @BuilderParam content: () => void;

  @State private pressed: boolean = false;

  build() {
    Column() {
      Column() {
        this.content()
      }
      .width('100%')
      .borderRadius(this.radius)
      .linearGradient({ angle: 145, colors: [[this.faceColors[0], 0], [this.faceColors[1], 1]] })
      .border({ width: 1, color: this.faceBorderColor })
      .padding(this.facePadding)
      .translate({ y: this.pressed ? this.depth - 2 : 0 })
      .animation({ duration: 110, curve: Curve.Sharp })
    }
    .width('100%')
    .padding({ bottom: this.depth })
    .borderRadius(this.radius)
    .backgroundColor(this.depthColor)
    .shadow({ radius: this.shadowRadius, color: this.shadowColor, offsetX: 0, offsetY: this.depth + 2 })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressed = false;
      }
    })
    .onClick(() => this.action())
  }
}
