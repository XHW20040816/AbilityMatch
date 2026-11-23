import { common } from '@kit.AbilityKit';
import { camera, cameraPicker } from '@kit.CameraKit';
import { promptAction, router } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { FileHelper } from '../common/FileHelper';
import { ResourceHelper } from '../common/ResourceHelper';
import { RouteHelper } from '../common/RouteHelper';
import { HonorCertificate, SkillDict } from '../model/Entity';
import { HonorLevel, HonorType } from '../model/Enums';
import { honorRepo } from '../repository/Repositories';
import { CertificateService } from '../service/CertificateService';

@Entry
@Component
struct CertificateEditPage {
  @State studentId: number = 1;
  @State certId: number = 0;
  @State title: string = '';
  @State honorTypeIndex: number = 0;
  @State levelIndex: number = 2;
  @State yearText: string = String(new Date().getFullYear());
  @State issuer: string = '';
  @State remark: string = '';
  @State imagePath: string = '';
  private service: CertificateService = new CertificateService();
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
  private honorTypes: HonorType[] = [HonorType.COMPETITION, HonorType.HONOR, HonorType.CERTIFICATE];
  private levels: HonorLevel[] = [HonorLevel.NATIONAL, HonorLevel.PROVINCIAL, HonorLevel.UNIVERSITY, HonorLevel.COLLEGE];
  private originalImagePath: string = '';
  private saved: boolean = false;

  aboutToAppear(): void {
    const params: Record<string, Object> = RouteHelper.params();
    if (params['studentId'] !== undefined) {
      this.studentId = Number(params['studentId']);
    }
    if (params['certId'] !== undefined) {
      this.certId = Number(params['certId']);
    }
    if (this.certId > 0) {
      honorRepo.getById(this.certId).then((cert: HonorCertificate | null) => {
        if (cert !== null) {
          this.title = cert.title;
          this.honorTypeIndex = Math.max(0, this.honorTypes.indexOf(cert.honorType));
          this.levelIndex = Math.max(0, this.levels.indexOf(cert.level));
          this.yearText = String(cert.awardYear);
          this.issuer = cert.issuer;
          this.remark = cert.remark;
          this.imagePath = cert.imagePath;
          this.originalImagePath = cert.imagePath;
        }
      });
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
        this.imagePath = await FileHelper.saveImage(this.context, result.resultUri);
      }
    } catch (error) {
      promptAction.showToast({ message: '拍照失败' });
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
        this.imagePath = await FileHelper.saveImage(this.context, result.photoUris[0]);
      }
    } catch (error) {
      promptAction.showToast({ message: '选择图片失败' });
    }
  }

  private save(): void {
    if (this.title.trim().length === 0) {
      promptAction.showToast({ message: '请输入证书或奖项名称' });
      return;
    }
    const year: number = Number(this.yearText);
    if (year < 2000 || year > new Date().getFullYear()) {
      promptAction.showToast({ message: '年份超出有效范围' });
      return;
    }
    const cert: HonorCertificate = {
      id: this.certId,
      studentId: this.studentId,
      title: this.title.trim(),
      honorType: this.honorTypes[this.honorTypeIndex],
      level: this.levels[this.levelIndex],
      awardYear: year,
      issuer: this.issuer.trim(),
      imagePath: this.imagePath,
      remark: this.remark.trim(),
      searchText: '',
      createTime: Date.now()
    };
    const oldPath: string = this.originalImagePath;
    ResourceHelper.loadSkillDict(this.context).then((dict: SkillDict) => {
      return this.service.save(cert, dict);
    }).then(() => {
      if (oldPath.length > 0 && oldPath !== this.imagePath) {
        FileHelper.removeFile(this.context, oldPath);
      }
      this.originalImagePath = this.imagePath;
      this.saved = true;
      promptAction.showToast({ message: '保存成功' });
      router.back();
    }).catch((error: Error) => {
      promptAction.showToast({ message: '保存失败：' + error.message });
    });
  }

  aboutToDisappear(): void {
    if (!this.saved && this.imagePath.length > 0 && this.imagePath !== this.originalImagePath) {
      FileHelper.removeFile(this.context, this.imagePath);
    }
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Text(this.certId > 0 ? '编辑证书' : '新增证书').fontSize(20).fontWeight(FontWeight.Bold)

      Row({ space: 12 }) {
        if (this.imagePath.length > 0) {
          Image(FileHelper.thumbnailPath(this.context, this.imagePath))
            .width(100).height(100).borderRadius(10).objectFit(ImageFit.Cover)
        } else {
          Column() {
            Text('暂无图片').fontSize(12).fontColor($r('app.color.text_secondary'))
          }
          .width(100).height(100).borderRadius(10).backgroundColor($r('app.color.surface_muted'))
          .justifyContent(FlexAlign.Center)
        }
        Column({ space: 8 }) {
          Button('拍照录入').fontSize(13).onClick(() => this.takePhoto())
          Button('从相册选择').fontSize(13).backgroundColor($r('app.color.success')).onClick(() => this.pickFromAlbum())
        }
      }
      .width('100%')

      TextInput({ placeholder: '证书/奖项名称', text: this.title })
        .width('100%')
        .onChange((value: string) => { this.title = value; })

      Row({ space: 8 }) {
        Select([{ value: '竞赛获奖' }, { value: '荣誉称号' }, { value: '技能证书' }])
          .selected(this.honorTypeIndex)
          .layoutWeight(1)
          .onSelect((index: number) => { this.honorTypeIndex = index; })
        Select([{ value: '国家级' }, { value: '省级' }, { value: '校级' }, { value: '院级' }])
          .selected(this.levelIndex)
          .layoutWeight(1)
          .onSelect((index: number) => { this.levelIndex = index; })
      }
      .width('100%')

      Row({ space: 8 }) {
        TextInput({ placeholder: '获奖年份', text: this.yearText })
          .width(110)
          .onChange((value: string) => { this.yearText = value; })
        TextInput({ placeholder: '颁发单位', text: this.issuer })
          .layoutWeight(1)
          .onChange((value: string) => { this.issuer = value; })
      }
      .width('100%')

      TextArea({ placeholder: '备注（可选）', text: this.remark })
        .width('100%')
        .height(90)
        .onChange((value: string) => { this.remark = value; })

        Button('保存').width('100%').onClick(() => this.save())
      }
      .width('100%')
      .padding(20)
      .linearGradient({ angle: 165, colors: [[$r('app.color.app_background'), 0], [$r('app.color.app_background_end'), 1]] })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }
}
