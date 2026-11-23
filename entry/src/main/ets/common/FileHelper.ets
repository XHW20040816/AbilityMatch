import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { Logger } from './Logger';

export interface ImageStats {
  fileCount: number;
  totalBytes: number;
  thumbCount: number;
}

class FileHelperClass {
  private ensureDir(path: string): void {
    if (!fileIo.accessSync(path)) {
      fileIo.mkdirSync(path, true);
    }
  }

  certsDir(context: common.UIAbilityContext): string {
    const dir: string = `${context.filesDir}/certs`;
    this.ensureDir(dir);
    return dir;
  }

  exportsDir(context: common.UIAbilityContext): string {
    const dir: string = `${context.filesDir}/exports`;
    this.ensureDir(dir);
    return dir;
  }

  verifyDir(context: common.UIAbilityContext): string {
    const dir: string = `${context.filesDir}/verifications`;
    this.ensureDir(dir);
    return dir;
  }

  absolutePath(context: common.UIAbilityContext, relativePath: string): string {
    if (relativePath.startsWith('/')) {
      return relativePath;
    }
    return `${context.filesDir}/${relativePath}`;
  }

  async saveImage(context: common.UIAbilityContext, uri: string): Promise<string> {
    const fileName: string = `${Date.now()}_${Math.floor(Math.random() * 100000)}.jpg`;
    const dest: string = `${this.certsDir(context)}/${fileName}`;
    const thumb: string = this.thumbnailAbsolute(context, `certs/${fileName}`);
    try {
      await this.compressImage(uri, dest, thumb, 1280, 420);
    } catch (error) {
      Logger.info('Image compression failed, fallback to copy: ' + (error as Error).message);
      await this.copyImage(uri, dest);
    }
    Logger.info('Image saved: ' + fileName);
    return `certs/${fileName}`;
  }

  thumbnailPath(context: common.UIAbilityContext, relativePath: string): string {
    const path: string = this.thumbnailAbsolute(context, relativePath);
    if (relativePath.length > 0 && fileIo.accessSync(path)) {
      return path;
    }
    return this.absolutePath(context, relativePath);
  }

  private thumbnailAbsolute(context: common.UIAbilityContext, relativePath: string): string {
    if (relativePath.length === 0) {
      return '';
    }
    const dot: number = relativePath.lastIndexOf('.');
    const relative: string = dot > 0
      ? `${relativePath.substring(0, dot)}_thumb${relativePath.substring(dot)}`
      : `${relativePath}_thumb`;
    return this.absolutePath(context, relative);
  }

  private async compressImage(uri: string, dest: string, thumbDest: string,
                              maxSize: number, thumbSize: number): Promise<void> {
    const sourceFile: fileIo.File = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
    let sourceFd: number = sourceFile.fd;
    let imageSource: image.ImageSource | null = null;
    let packer: image.ImagePacker | null = null;
    try {
      imageSource = image.createImageSource(sourceFd);
      const info: image.ImageInfo = await imageSource.getImageInfo();
      const originalSize: number[] = this.fitSize(info.size.width, info.size.height, maxSize);
      const large: image.PixelMap = await imageSource.createPixelMap({
        desiredSize: { width: originalSize[0], height: originalSize[1] }
      });
      packer = image.createImagePacker();
      const data: ArrayBuffer = await packer.packToData(large, { format: 'image/jpeg', quality: 68 });
      this.writeBuffer(dest, data);
      large.release();
      const smallSize: number[] = this.fitSize(info.size.width, info.size.height, thumbSize);
      const small: image.PixelMap = await imageSource.createPixelMap({
        desiredSize: { width: smallSize[0], height: smallSize[1] }
      });
      const thumbData: ArrayBuffer = await packer.packToData(small, { format: 'image/jpeg', quality: 55 });
      this.writeBuffer(thumbDest, thumbData);
      small.release();
    } finally {
      if (packer !== null) {
        packer.release();
      }
      if (imageSource !== null) {
        imageSource.release();
      }
      if (sourceFd >= 0) {
        fileIo.closeSync(sourceFd);
      }
    }
  }

  private fitSize(width: number, height: number, max: number): number[] {
    if (width <= 0 || height <= 0) {
      return [max, max];
    }
    const scale: number = Math.min(1, max / Math.max(width, height));
    return [Math.max(1, Math.round(width * scale)), Math.max(1, Math.round(height * scale))];
  }

  private writeBuffer(path: string, data: ArrayBuffer): void {
    const file: fileIo.File = fileIo.openSync(
      path, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC
    );
    try {
      fileIo.writeSync(file.fd, data);
    } finally {
      fileIo.closeSync(file.fd);
    }
  }

  async cleanupOrphans(context: common.UIAbilityContext, referenced: string[]): Promise<number> {
    const dir: string = this.certsDir(context);
    const keep: string[] = [];
    for (const relative of referenced) {
      if (!relative.startsWith('certs/')) {
        continue;
      }
      const name: string = relative.substring('certs/'.length);
      keep.push(name);
      const dot: number = name.lastIndexOf('.');
      keep.push(dot > 0 ? `${name.substring(0, dot)}_thumb${name.substring(dot)}` : `${name}_thumb`);
    }
    let removed: number = 0;
    try {
      const files: string[] = fileIo.listFileSync(dir);
      for (const name of files) {
        if (keep.indexOf(name) >= 0) {
          continue;
        }
        try {
          fileIo.unlinkSync(`${dir}/${name}`);
          removed++;
        } catch (error) {
          Logger.info('Skip orphan file: ' + name);
        }
      }
    } catch (error) {
      Logger.info('Cleanup skipped: ' + (error as Error).message);
    }
    return removed;
  }

  // 统计证书图片目录占用：文件数、总字节、缩略图数量
  imageStats(context: common.UIAbilityContext): ImageStats {
    const dir: string = this.certsDir(context);
    const stats: ImageStats = { fileCount: 0, totalBytes: 0, thumbCount: 0 };
    try {
      const files: string[] = fileIo.listFileSync(dir);
      for (const name of files) {
        stats.fileCount += 1;
        if (name.indexOf('_thumb') >= 0) {
          stats.thumbCount += 1;
        }
        try {
          stats.totalBytes += fileIo.statSync(`${dir}/${name}`).size;
        } catch (error) {
          Logger.info('Stat skipped: ' + name);
        }
      }
    } catch (error) {
      Logger.info('Image stats skipped: ' + (error as Error).message);
    }
    return stats;
  }

  // 清理缩略图缓存（原图保留，下次预览会重新按需生成）
  clearThumbnails(context: common.UIAbilityContext): number {
    const dir: string = this.certsDir(context);
    let removed: number = 0;
    try {
      const files: string[] = fileIo.listFileSync(dir);
      for (const name of files) {
        if (name.indexOf('_thumb') < 0) {
          continue;
        }
        try {
          fileIo.unlinkSync(`${dir}/${name}`);
          removed += 1;
        } catch (error) {
          Logger.info('Skip thumbnail: ' + name);
        }
      }
    } catch (error) {
      Logger.info('Clear thumbnails skipped: ' + (error as Error).message);
    }
    return removed;
  }

  async saveVerificationImage(context: common.UIAbilityContext, uri: string): Promise<string> {
    const fileName: string = `verify_${Date.now()}_${Math.floor(Math.random() * 100000)}.jpg`;
    await this.copyImage(uri, `${this.verifyDir(context)}/${fileName}`);
    Logger.info('Verification image saved: ' + fileName);
    return `verifications/${fileName}`;
  }

  private async copyImage(uri: string, dest: string): Promise<void> {
    let sourceFd: number = -1;
    let destFd: number = -1;
    try {
      const sourceFile: fileIo.File = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      sourceFd = sourceFile.fd;
      const destFile: fileIo.File = fileIo.openSync(
        dest, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC
      );
      destFd = destFile.fd;
      const buffer: ArrayBuffer = new ArrayBuffer(64 * 1024);
      let bytesRead: number = 0;
      do {
        bytesRead = fileIo.readSync(sourceFd, buffer);
        if (bytesRead > 0) {
          fileIo.writeSync(destFd, buffer.slice(0, bytesRead));
        }
      } while (bytesRead > 0);
    } finally {
      if (sourceFd >= 0) {
        fileIo.closeSync(sourceFd);
      }
      if (destFd >= 0) {
        fileIo.closeSync(destFd);
      }
    }
  }

  removeFile(context: common.UIAbilityContext, relativePath: string): void {
    if (relativePath.length === 0) {
      return;
    }
    const path: string = this.absolutePath(context, relativePath);
    const thumb: string = this.thumbnailAbsolute(context, relativePath);
    try {
      if (fileIo.accessSync(path)) {
        fileIo.unlinkSync(path);
      }
      if (fileIo.accessSync(thumb)) {
        fileIo.unlinkSync(thumb);
      }
    } catch (error) {
      Logger.error('Failed to remove file: ' + path);
    }
  }

  writeTextFile(path: string, content: string): void {
    const file: fileIo.File = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
    try {
      fileIo.writeSync(file.fd, content);
    } finally {
      fileIo.closeSync(file.fd);
    }
  }

  exportFile(context: common.UIAbilityContext, fileName: string, content: string): string {
    const path: string = `${this.exportsDir(context)}/${fileName}`;
    this.writeTextFile(path, content);
    Logger.info('File exported: ' + path);
    return path;
  }
}

export const FileHelper: FileHelperClass = new FileHelperClass();
