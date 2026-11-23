import { common } from '@kit.AbilityKit';
import { camera, cameraPicker } from '@kit.CameraKit';
import { promptAction, router } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { FileHelper } from '../common/FileHelper';
import { Style3D } from '../common/Style3D';
import { Card3D } from '../view/Card3D';
import { SelectItem } from '../model/Entity';
import { AppRole } from '../model/Enums';
import { authService } from '../service/AuthService';
import { AppViewModel } from '../viewmodel/AppViewModel';

@Extend(TextInput)
function authInputStyle() {
  .height(48)
  .width('100%')
  .fontSize(14)
  .fontColor($r('app.color.text_primary'))
  .placeholderColor($r('app.color.text_tertiary'))
  .backgroundColor($r('app.color.surface_muted'))
  .borderRadius(14)
  .padding({ left: 14, right: 14 })
}

@Extend(Select)
function authSelectStyle() {
  .width('100%')
  .height(48)
  .backgroundColor($r('app.color.surface_muted'))
  .borderRadius(14)
}

@Entry
@Component
struct AuthPage {
  @State role: AppRole = AppRole.STUDENT;
  @State mode: string = 'login';
  @State account: string = '';
  @State password: string = '';
  @State confirmPassword: string = '';

  @State name: string = '';
  @State studentNo: string = '';
  @State school: string = '';
  @State major: string = '';
  @State educationIndex: number = 1;
  @State schoolLevelIndex: number = -1;
  @State gradeIndex: number = 2;

  @State companyName: string = '';
  @State industryIndex: number = 0;
  @State scaleIndex: number = 1;
  @State contactPerson: string = '';
  @State address: string = '';

  @State verifyImagePath: string = '';
  @State submitting: boolean = false;
  @State saved: boolean = false;
  /** 登录页彩蛋：点击顶部立体卡片弹出「Offer 看到你啦」插画 */
  @State showEgg: boolean = false;

  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  private educations: string[] = ['高中学历及以下', '本科', '专科', '专升本', '硕士', '博士及以上'];
  private schoolLevels: string[] = ['985', '211', '双一流', '留学', '其他'];
  private grades: string[] = ['大一', '大二', '大三', '大四', '研一', '研二', '研三'];
  private industries: string[] = ['互联网 / 软件', '智能制造', '金融', '教育', '医疗健康', '其他'];
  private scales: string[] = ['1-50 人', '51-200 人', '201-500 人', '500 人以上'];

  aboutToDisappear(): void {
    if (!this.saved && this.verifyImagePath.length > 0) {
      FileHelper.removeFile(this.context, this.verifyImagePath);
    }
  }

  private openEgg(): void {
    animateTo({ duration: 260, curve: Curve.FastOutSlowIn }, () => {
      this.showEgg = true;
    });
  }

  private closeEgg(): void {
    animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => {
      this.showEgg = false;
    });
  }

  onBackPress(): boolean {
    if (this.showEgg) {
      this.closeEgg();
      return true;
    }
    return false;
  }

  private isStudent(): boolean {
    return this.role === AppRole.STUDENT;
  }

  private needsSchoolLevel(): boolean {
    const education: string = this.educations[this.educationIndex];
    return education === '本科' || education === '硕士' || education === '博士及以上';
  }

  private switchRole(role: AppRole): void {
    if (this.role === role) {
      return;
    }
    if (!this.saved && this.verifyImagePath.length > 0) {
      FileHelper.removeFile(this.context, this.verifyImagePath);
    }
    this.role = role;
    this.verifyImagePath = '';
    this.saved = false;
  }

  private showError(message: string): void {
    promptAction.showToast({ message: message });
  }

  private validate(): boolean {
    if (this.account.trim().length < 4) {
      this.showError('请输入手机号或邮箱作为登录账号');
      return false;
    }
    if (this.password.length < 6) {
      this.showError('密码至少 6 位');
      return false;
    }
    if (this.mode === 'login') {
      return true;
    }
    if (this.password !== this.confirmPassword) {
      this.showError('两次输入的密码不一致');
      return false;
    }
    if (this.isStudent()) {
      if (this.name.trim().length === 0 || this.studentNo.trim().length === 0) {
        this.showError('请填写姓名和学号');
        return false;
      }
      if (this.school.trim().length === 0 || this.major.trim().length === 0) {
        this.showError('请填写学校和专业');
        return false;
      }
      if (this.needsSchoolLevel() && this.schoolLevelIndex < 0) {
        this.showError('请选择学校层级');
        return false;
      }
    } else {
      if (this.companyName.trim().length === 0 || this.contactPerson.trim().length === 0) {
        this.showError('请填写企业名称和联系人');
        return false;
      }
    }
    if (this.verifyImagePath.length === 0) {
      this.showError(this.isStudent() ? '请上传学信网学籍在线验证报告' : '请上传企业营业执照或企业证明');
      return false;
    }
    return true;
  }

  private async submit(): Promise<void> {
    if (this.submitting || !this.validate()) {
      return;
    }
    this.submitting = true;
    try {
      if (this.mode === 'login') {
        await authService.login(this.role, this.account, this.password);
      } else if (this.isStudent()) {
        await authService.registerStudent({
          name: this.name,
          studentNo: this.studentNo,
          school: this.school,
          schoolLevel: this.needsSchoolLevel() && this.schoolLevelIndex >= 0 ?
            this.schoolLevels[this.schoolLevelIndex] : '',
          major: this.major,
          education: this.educations[this.educationIndex],
          grade: this.grades[this.gradeIndex],
          account: this.account,
          password: this.password,
          verifyImagePath: this.verifyImagePath
        });
      } else {
        await authService.registerCompany({
          companyName: this.companyName,
          industry: this.industries[this.industryIndex],
          scale: this.scales[this.scaleIndex],
          contactPerson: this.contactPerson,
          address: this.address,
          account: this.account,
          password: this.password,
          verifyImagePath: this.verifyImagePath
        });
      }
      this.saved = true;
      await AppViewModel.load();
      router.replaceUrl({ url: 'pages/Index' });
    } catch (error) {
      const message: string = error instanceof Error ? error.message : '操作失败，请重试';
      this.showError(message);
    } finally {
      this.submitting = false;
    }
  }

  private async pickFromAlbum(): Promise<void> {
    try {
      const picker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const options: photoAccessHelper.PhotoSelectOptions = {
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      };
      const result: photoAccessHelper.PhotoSelectResult = await picker.select(options);
      if (result.photoUris.length > 0) {
        this.replaceVerifyImage(await FileHelper.saveVerificationImage(this.context, result.photoUris[0]));
      }
    } catch (error) {
      this.showError('选择图片失败');
    }
  }

  private async takePhoto(): Promise<void> {
    try {
      const profile: cameraPicker.PickerProfile = {
        cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK
      };
      const result: cameraPicker.PickerResult = await cameraPicker.pick(
        this.context, [cameraPicker.PickerMediaType.PHOTO], profile
      );
      if (result.resultCode === 0 && result.resultUri.length > 0) {
        this.replaceVerifyImage(await FileHelper.saveVerificationImage(this.context, result.resultUri));
      }
    } catch (error) {
      this.showError('拍照失败');
    }
  }

  private replaceVerifyImage(path: string): void {
    if (this.verifyImagePath.length > 0) {
      FileHelper.removeFile(this.context, this.verifyImagePath);
    }
    this.verifyImagePath = path;
    this.saved = false;
  }

  @Builder
  fieldLabel(text: string) {
    Text(text)
      .fontSize(12)
      .fontColor($r('app.color.text_secondary'))
      .width('100%')
      .margin({ bottom: 6 })
  }

  @Builder
  uploadCard() {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 4 }) {
          Text(this.isStudent() ? '学信网学籍在线验证报告' : '企业营业执照 / 企业证明')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Text(this.isStudent() ? '需包含姓名、学校、学号与有效验证码' : '需包含企业名称、统一社会信用代码')
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Text('必传')
          .fontSize(10)
          .fontColor($r('app.color.brand_primary'))
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .borderRadius(10)
          .backgroundColor($r('app.color.chip_background'))
      }
      .width('100%')

      if (this.verifyImagePath.length > 0) {
        Image(FileHelper.absolutePath(this.context, this.verifyImagePath))
          .width('100%')
          .height(148)
          .objectFit(ImageFit.Cover)
          .borderRadius(16)
      } else {
        Column({ space: 6 }) {
          Text('+')
            .fontSize(28)
            .fontWeight(FontWeight.Lighter)
            .fontColor($r('app.color.brand_primary'))
          Text(this.isStudent() ? '上传学信网证明' : '上传企业证明')
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .height(120)
        .justifyContent(FlexAlign.Center)
        .borderRadius(16)
        .border({
          width: 1,
          color: $r('app.color.brand_primary'),
          style: BorderStyle.Dashed
        })
        .backgroundColor($r('app.color.brand_soft'))
      }

      Row({ space: 10 }) {
        Button('从相册选择')
          .layoutWeight(1)
          .height(38)
          .fontSize(12)
          .borderRadius(19)
          .backgroundColor($r('app.color.brand_primary'))
          .fontColor($r('app.color.on_primary'))
          .onClick(() => this.pickFromAlbum())
        Button('拍照')
          .layoutWeight(1)
          .height(38)
          .fontSize(12)
          .borderRadius(19)
          .backgroundColor($r('app.color.accent_peach_soft'))
          .fontColor($r('app.color.text_primary'))
          .onClick(() => this.takePhoto())
      }
      .width('100%')

      Text('证明材料仅保存在本机应用沙箱，用于身份核验展示')
        .fontSize(10)
        .fontColor($r('app.color.text_tertiary'))
    }
    .width('100%')
    .padding(14)
    .borderRadius(18)
    .backgroundColor($r('app.color.card_background'))
    .border({ width: 1, color: $r('app.color.chip_background') })
  }

  @Builder
  studentFields() {
    Column({ space: 12 }) {
      Column() {
        this.fieldLabel('姓名')
        TextInput({ placeholder: '请输入真实姓名', text: this.name })
          .onChange((value: string) => { this.name = value; })
          .authInputStyle()
      }
      .width('100%')

      Column() {
        this.fieldLabel('学号')
        TextInput({ placeholder: '请输入学号', text: this.studentNo })
          .onChange((value: string) => { this.studentNo = value; })
          .authInputStyle()
      }
      .width('100%')

      Column() {
        this.fieldLabel('学校')
        TextInput({ placeholder: '请输入学校全称', text: this.school })
          .onChange((value: string) => { this.school = value; })
          .authInputStyle()
      }
      .width('100%')

      Column() {
        this.fieldLabel('专业')
        TextInput({ placeholder: '请输入专业名称', text: this.major })
          .onChange((value: string) => { this.major = value; })
          .authInputStyle()
      }
      .width('100%')

      Row({ space: 10 }) {
        Column() {
          this.fieldLabel('学历')
          Select(this.educations.map((value: string): SelectItem => ({ value: value })))
            .selected(this.educationIndex)
            .value(this.educations[this.educationIndex])
            .onSelect((index: number) => { this.educationIndex = index; })
            .authSelectStyle()
        }
        .layoutWeight(1)

        Column() {
          this.fieldLabel('年级')
          Select(this.grades.map((value: string): SelectItem => ({ value: value })))
            .selected(this.gradeIndex)
            .value(this.grades[this.gradeIndex])
            .onSelect((index: number) => { this.gradeIndex = index; })
            .authSelectStyle()
        }
        .layoutWeight(1)
      }
      .width('100%')

      if (this.needsSchoolLevel()) {
        Column() {
          this.fieldLabel('学校层级')
          Select(this.schoolLevels.map((value: string): SelectItem => ({ value: value })))
            .selected(this.schoolLevelIndex)
            .value(this.schoolLevelIndex >= 0 ? this.schoolLevels[this.schoolLevelIndex] : '请选择')
            .onSelect((index: number) => { this.schoolLevelIndex = index; })
            .authSelectStyle()
        }
        .width('100%')
      }
    }
    .width('100%')
  }

  @Builder
  companyFields() {
    Column({ space: 12 }) {
      Column() {
        this.fieldLabel('企业名称')
        TextInput({ placeholder: '请输入企业全称', text: this.companyName })
          .onChange((value: string) => { this.companyName = value; })
          .authInputStyle()
      }
      .width('100%')

      Row({ space: 10 }) {
        Column() {
          this.fieldLabel('所属行业')
          Select(this.industries.map((value: string): SelectItem => ({ value: value })))
            .selected(this.industryIndex)
            .value(this.industries[this.industryIndex])
            .onSelect((index: number) => { this.industryIndex = index; })
            .authSelectStyle()
        }
        .layoutWeight(1)

        Column() {
          this.fieldLabel('企业规模')
          Select(this.scales.map((value: string): SelectItem => ({ value: value })))
            .selected(this.scaleIndex)
            .value(this.scales[this.scaleIndex])
            .onSelect((index: number) => { this.scaleIndex = index; })
            .authSelectStyle()
        }
        .layoutWeight(1)
      }
      .width('100%')

      Column() {
        this.fieldLabel('联系人')
        TextInput({ placeholder: '请输入招聘联系人姓名', text: this.contactPerson })
          .onChange((value: string) => { this.contactPerson = value; })
          .authInputStyle()
      }
      .width('100%')

      Column() {
        this.fieldLabel('办公地址')
        TextInput({ placeholder: '请输入企业办公地址', text: this.address })
          .onChange((value: string) => { this.address = value; })
          .authInputStyle()
      }
      .width('100%')
    }
    .width('100%')
  }

  build() {
    Stack() {
      Column() {
        Scroll() {
          Column({ space: 16 }) {
            Card3D({
              faceColors: Style3D.heroFace,
              depthColor: Style3D.heroDepth,
              radius: 26,
              depth: 8,
              facePadding: 20,
              faceBorderColor: '#40FFFFFF',
              shadowColor: Style3D.shadowDeep,
              shadowRadius: 24,
              action: () => this.openEgg()
              }) {
              Row({ space: 14 }) {
                Column({ space: 6 }) {
                  Text('BOSS智聘')
                    .fontSize(26)
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.on_primary'))
                  Text('学生成长 × 企业招聘')
                    .fontSize(12)
                    .fontColor('#D9FFFFFF')
                  Text('找到更适合的第一步')
                    .fontSize(12)
                    .fontColor('#BFFFFFFF')
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Column() {
                  Text('聘')
                    .fontSize(30)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#0A7C92')
                }
                .width(58)
                .height(58)
                .justifyContent(FlexAlign.Center)
                .borderRadius(18)
                .linearGradient({ angle: 150, colors: [['#FFFFFF', 0], ['#D9F6F4', 1]] })
                .border({ width: 1, color: '#80FFFFFF' })
                .shadow({ radius: 10, color: '#4D06596B', offsetX: 0, offsetY: 5 })
                .rotate({ angle: -6 })
              }
              .width('100%')
            }

            Row({ space: 6 }) {
              Button('我是学生')
                .layoutWeight(1)
                .height(42)
                .fontSize(13)
                .borderRadius(21)
                .backgroundColor(this.isStudent() ? $r('app.color.brand_primary') : Color.Transparent)
                .fontColor(this.isStudent() ? $r('app.color.on_primary') : $r('app.color.text_secondary'))
                .onClick(() => this.switchRole(AppRole.STUDENT))
              Button('我是企业')
                .layoutWeight(1)
                .height(42)
                .fontSize(13)
                .borderRadius(21)
                .backgroundColor(!this.isStudent() ? $r('app.color.brand_primary') : Color.Transparent)
                .fontColor(!this.isStudent() ? $r('app.color.on_primary') : $r('app.color.text_secondary'))
                .onClick(() => this.switchRole(AppRole.COMPANY))
            }
            .width('100%')
            .padding(4)
            .borderRadius(25)
            .backgroundColor($r('app.color.card_background'))

            Row({ space: 4 }) {
              Text('登录')
                .layoutWeight(1)
                .height(36)
                .fontSize(13)
                .fontWeight(this.mode === 'login' ? FontWeight.Medium : FontWeight.Normal)
                .fontColor(this.mode === 'login' ? $r('app.color.text_primary') : $r('app.color.text_tertiary'))
                .textAlign(TextAlign.Center)
                .borderRadius(18)
                .backgroundColor(this.mode === 'login' ? $r('app.color.accent_peach_soft') : Color.Transparent)
                .onClick(() => { this.mode = 'login'; })
              Text('注册')
                .layoutWeight(1)
                .height(36)
                .fontSize(13)
                .fontWeight(this.mode === 'register' ? FontWeight.Medium : FontWeight.Normal)
                .fontColor(this.mode === 'register' ? $r('app.color.text_primary') : $r('app.color.text_tertiary'))
                .textAlign(TextAlign.Center)
                .borderRadius(18)
                .backgroundColor(this.mode === 'register' ? $r('app.color.accent_peach_soft') : Color.Transparent)
                .onClick(() => { this.mode = 'register'; })
            }
            .width('100%')
            .padding(3)
            .borderRadius(21)
            .backgroundColor($r('app.color.surface_muted'))

            Column({ space: 14 }) {
              if (this.mode === 'register') {
                if (this.isStudent()) {
                  this.studentFields()
                } else {
                  this.companyFields()
                }
              }

              Column() {
                this.fieldLabel(this.mode === 'login' ? '登录账号' : (this.isStudent() ? '手机号 / 邮箱' : '企业登录手机号 / 邮箱'))
                TextInput({ placeholder: '手机号或邮箱', text: this.account })
                  .type(InputType.Normal)
                  .onChange((value: string) => { this.account = value; })
                  .authInputStyle()
                if (this.mode === 'login') {
                  Text(this.isStudent() ? '学生账号与企业账号相互独立' : '使用企业注册时填写的账号登录')
                    .fontSize(10)
                    .fontColor($r('app.color.text_tertiary'))
                    .width('100%')
                    .margin({ top: 5 })
                }
              }
              .width('100%')

              Column() {
                this.fieldLabel('密码')
                TextInput({ placeholder: '至少 6 位密码', text: this.password })
                  .type(InputType.Password)
                  .onChange((value: string) => { this.password = value; })
                  .authInputStyle()
              }
              .width('100%')

              if (this.mode === 'register') {
                Column() {
                  this.fieldLabel('确认密码')
                  TextInput({ placeholder: '再次输入密码', text: this.confirmPassword })
                    .type(InputType.Password)
                    .onChange((value: string) => { this.confirmPassword = value; })
                    .authInputStyle()
                }
                .width('100%')

                this.uploadCard()
              }

              Button(this.submitting ? '请稍候...' : (this.mode === 'login' ? '登录' : '提交注册'))
                .width('100%')
                .height(50)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .borderRadius(25)
                .linearGradient({ angle: 135, colors: [[Style3D.heroFace[0], 0], [Style3D.heroFace[1], 1]] })
                .fontColor($r('app.color.on_primary'))
                .border({ width: 1, color: Style3D.highlight })
                .enabled(!this.submitting)
                .shadow({ radius: 14, color: '#4D0A7C92', offsetX: 0, offsetY: 6 })
                .onClick(() => this.submit())

              Row({ space: 4 }) {
                Text(this.mode === 'login' ? '还没有账号？' : '已经有账号？')
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
                Text(this.mode === 'login' ? '立即注册' : '去登录')
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.brand_primary'))
                  .onClick(() => { this.mode = this.mode === 'login' ? 'register' : 'login'; })
              }
              .justifyContent(FlexAlign.Center)
              .width('100%')
            }
            .width('100%')
            .padding(16)
            .borderRadius(22)
            .backgroundColor($r('app.color.card_background'))
            .shadow({ radius: 12, color: $r('app.color.shadow'), offsetX: 0, offsetY: 4 })

            Text('BOSS智聘 · 本地演示版')
              .fontSize(10)
              .fontColor($r('app.color.text_tertiary'))
              .margin({ top: 2, bottom: 8 })
          }
          .width('100%')
          .padding({ left: 18, right: 18, top: 22, bottom: 20 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .linearGradient({
        angle: 165,
        colors: [[$r('app.color.app_background'), 0], [$r('app.color.app_background_end'), 1]]
      })

      if (this.showEgg) {
        Column() {
          Column({ space: 14 }) {
            Image($r('app.media.egg_offer'))
              .width('100%')
              .aspectRatio(1.11)
              .objectFit(ImageFit.Cover)
              .borderRadius(20)
              .border({ width: 1, color: '#1A0A4A55' })
              .shadow({ radius: 18, color: '#330E5C5C', offsetX: 0, offsetY: 8 })

            Text('Offer 看到你啦！')
              .fontSize(18)
              .lineHeight(26)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
              .textAlign(TextAlign.Center)
              .width('100%')

            Text('轻触任意位置，继续出发')
              .fontSize(11)
              .fontColor($r('app.color.text_tertiary'))

            Button('回去继续')
              .fontSize(14)
              .height(42)
              .width('100%')
              .borderRadius(21)
              .linearGradient({ angle: 135, colors: [['#3AD8DA', 0], ['#0FA3AE', 1]] })
              .border({ width: 1, color: '#4DFFFFFF' })
              .shadow({ radius: 12, color: '#400A8089', offsetX: 0, offsetY: 5 })
              .fontColor($r('app.color.on_primary'))
              .onClick(() => this.closeEgg())
          }
          .width('84%')
          .padding(16)
          .borderRadius(26)
          .linearGradient({ angle: 145, colors: [['#FFFFFF', 0], ['#F1FAF9', 1]] })
          .border({ width: 1, color: '#8CFFFFFF' })
          .shadow({ radius: 26, color: '#400E5C5C', offsetX: 0, offsetY: 12 })
          .onClick(() => {})
          .transition(TransitionEffect.scale({ x: 0.92, y: 0.92 }).combine(TransitionEffect.OPACITY))
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#8C04222B')
        .onClick(() => this.closeEgg())
        .transition(TransitionEffect.OPACITY)
        .zIndex(9)
      }
    }
    .width('100%')
    .height('100%')
  }
}
