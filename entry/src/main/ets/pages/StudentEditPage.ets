import { promptAction, router } from '@kit.ArkUI';
import { Taxonomy } from '../common/Taxonomy';
import { SelectItem, Student } from '../model/Entity';
import { studentRepo } from '../repository/Repositories';
import { AppViewModel } from '../viewmodel/AppViewModel';

@Entry
@Component
struct StudentEditPage {
  @State editing: Student = {
    id: 0,
    studentNo: '',
    name: '',
    school: '',
    schoolLevel: '',
    major: '',
    grade: '',
    education: '本科',
    direction: '软件开发',
    phone: '',
    email: '',
    isPublic: true
  };
  @State educationIndex: number = 3;
  @State schoolLevelIndex: number = -1;
  @State isPublic: boolean = true;
  private educationOptions: string[] = Taxonomy.educationOptions;
  private schoolLevelOptions: string[] = Taxonomy.schoolLevelOptions;

  aboutToAppear(): void {
    AppViewModel.load().then(() => {
      return studentRepo.getById(AppViewModel.studentId);
    }).then((student: Student | null) => {
      if (student !== null) {
        this.applyStudent(student);
      }
    }).catch((error: Error) => {
      promptAction.showToast({ message: '加载失败：' + error.message });
    });
  }

  private applyStudent(student: Student): void {
    this.editing = {
      id: student.id,
      studentNo: student.studentNo,
      name: student.name,
      school: student.school,
      schoolLevel: student.schoolLevel,
      major: student.major,
      grade: student.grade,
      education: student.education,
      direction: student.direction,
      phone: student.phone,
      email: student.email,
      isPublic: student.isPublic === undefined ? true : student.isPublic
    };
    this.editing.education = Taxonomy.normalizeEducation(student.education);
    const index: number = this.educationOptions.indexOf(this.editing.education);
    this.educationIndex = index >= 0 ? index : 3;
    this.isPublic = this.editing.isPublic === true;
    const levelIndex: number = this.schoolLevelOptions.indexOf(student.schoolLevel);
    this.schoolLevelIndex = levelIndex >= 0 ? levelIndex : -1;
  }

  private normalizeEducation(value: string): string {
    return Taxonomy.normalizeEducation(value);
  }

  private needsSchoolLevel(education: string): boolean {
    return education === '本科' || education === '硕士' || education === '博士及以上';
  }

  private onEducationSelect(index: number): void {
    this.educationIndex = index;
    this.editing.education = this.educationOptions[index];
    if (!this.needsSchoolLevel(this.editing.education)) {
      this.editing.schoolLevel = '';
      this.schoolLevelIndex = -1;
    }
  }

  private save(): void {
    if (this.editing.name.trim().length === 0 || this.editing.studentNo.trim().length === 0) {
      promptAction.showToast({ message: '请填写姓名与学号' });
      return;
    }
    if (this.editing.school.trim().length === 0) {
      promptAction.showToast({ message: '请填写学校' });
      return;
    }
    if (this.needsSchoolLevel(this.editing.education) && this.editing.schoolLevel.length === 0) {
      promptAction.showToast({ message: '请选择学校层级' });
      return;
    }
    const student: Student = {
      id: this.editing.id,
      studentNo: this.editing.studentNo.trim(),
      name: this.editing.name.trim(),
      school: this.editing.school.trim(),
      schoolLevel: this.editing.schoolLevel,
      major: this.editing.major.trim(),
      grade: this.editing.grade.trim(),
      education: this.editing.education,
      direction: this.editing.direction,
      phone: this.editing.phone.trim(),
      email: this.editing.email.trim(),
      isPublic: this.isPublic
    };
    studentRepo.save(student).then(() => {
      AppViewModel.studentName = student.name;
      promptAction.showToast({ message: '资料已保存' });
    }).catch((error: Error) => {
      promptAction.showToast({ message: '保存失败：' + error.message });
    });
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        Button('返回')
          .fontSize(12)
          .height(34)
          .borderRadius(17)
          .backgroundColor($r('app.color.surface_muted'))
          .fontColor($r('app.color.text_primary'))
          .onClick(() => router.back())
        Text('学生资料')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Button('保存资料')
          .fontSize(13)
          .height(36)
          .borderRadius(18)
          .backgroundColor($r('app.color.brand_primary'))
          .fontColor($r('app.color.on_primary'))
          .onClick(() => this.save())
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 18 })

      Scroll() {
        Column({ space: 12 }) {
          Text('学籍信息')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')

          TextInput({ placeholder: '姓名', text: this.editing.name })
            .width('100%').onChange((value: string) => { this.editing.name = value; })
          TextInput({ placeholder: '学号', text: this.editing.studentNo })
            .width('100%').onChange((value: string) => { this.editing.studentNo = value; })
          TextInput({ placeholder: '学校全称', text: this.editing.school })
            .width('100%').onChange((value: string) => { this.editing.school = value; })
          TextInput({ placeholder: '专业', text: this.editing.major })
            .width('100%').onChange((value: string) => { this.editing.major = value; })
          TextInput({ placeholder: '年级，如大三/研一', text: this.editing.grade })
            .width('100%').onChange((value: string) => { this.editing.grade = value; })

          Row({ space: 8 }) {
            Text('学历').fontSize(13).fontColor($r('app.color.text_secondary'))
            Select(this.educationOptions.map((value: string): SelectItem => ({ value: value })))
              .selected(this.educationIndex)
              .value(this.educationOptions[this.educationIndex])
              .layoutWeight(1)
              .onSelect((index: number) => this.onEducationSelect(index))
          }
          .width('100%')

          if (this.needsSchoolLevel(this.editing.education)) {
            Row({ space: 8 }) {
              Text('学校层级').fontSize(13).fontColor($r('app.color.text_secondary'))
              Select(this.schoolLevelOptions.map((value: string): SelectItem => ({ value: value })))
                .selected(this.schoolLevelIndex)
                .value(this.schoolLevelIndex >= 0 ? this.schoolLevelOptions[this.schoolLevelIndex] : '请选择')
                .layoutWeight(1)
                .onSelect((index: number) => {
                  this.schoolLevelIndex = index;
                  this.editing.schoolLevel = this.schoolLevelOptions[index];
                })
            }
            .width('100%')
          }

          Text('成长与联系')
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .margin({ top: 6 })

          TextInput({ placeholder: '专业方向', text: this.editing.direction })
            .width('100%').onChange((value: string) => { this.editing.direction = value; })
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(Taxonomy.directionOptions, (direction: string) => {
              Text(direction).fontSize(11)
                .fontColor(this.editing.direction === direction ? $r('app.color.on_primary') : $r('app.color.text_label'))
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .margin({ right: 6, bottom: 6 })
                .borderRadius(14)
                .backgroundColor(this.editing.direction === direction ?
                  $r('app.color.brand_primary') : $r('app.color.chip_background'))
                .onClick(() => { this.editing.direction = direction; })
            }, (direction: string) => direction)
          }
          .width('100%')
          Row({ space: 8 }) {
            Column({ space: 2 }) {
              Text('公开求职档案').fontSize(13).fontColor($r('app.color.text_primary'))
              Text('关闭后企业候选人列表不再展示你的资料').fontSize(10)
                .fontColor($r('app.color.text_secondary'))
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            Toggle({ type: ToggleType.Switch, isOn: this.isPublic })
              .selectedColor($r('app.color.brand_primary'))
              .onChange((value: boolean) => { this.isPublic = value; })
          }
          .width('100%')
          .padding(10)
          .borderRadius(12)
          .backgroundColor($r('app.color.card_background'))
          TextInput({ placeholder: '手机号', text: this.editing.phone })
            .width('100%').onChange((value: string) => { this.editing.phone = value; })
          TextInput({ placeholder: '邮箱', text: this.editing.email })
            .width('100%').onChange((value: string) => { this.editing.email = value; })

          Text('账号已绑定该学生身份，注册时提交的学信网证明可在本机核验。')
            .fontSize(11)
            .fontColor($r('app.color.text_tertiary'))
            .width('100%')
            .padding(12)
            .borderRadius(12)
            .backgroundColor($r('app.color.brand_soft'))
        }
        .width('100%')
        .padding({ left: 18, right: 18, bottom: 20 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .linearGradient({ angle: 165, colors: [[$r('app.color.app_background'), 0], [$r('app.color.app_background_end'), 1]] })
  }
}
