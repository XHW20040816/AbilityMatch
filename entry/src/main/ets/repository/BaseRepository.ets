import { ValueType } from '@kit.ArkData';

export class BaseRepository {
  static num(value: ValueType | Uint8Array | null | undefined): number {
    if (value === null || value === undefined || value === '') {
      return 0;
    }
    return Number(value);
  }

  static str(value: ValueType | Uint8Array | null | undefined): string {
    if (value === null || value === undefined) {
      return '';
    }
    return String(value);
  }

  static bool(value: ValueType | Uint8Array | null | undefined): boolean {
    return value === 1 || value === '1' || value === true;
  }

  static arr(value: ValueType | Uint8Array | null | undefined): string[] {
    const text: string = BaseRepository.str(value);
    if (text.length === 0) {
      return [];
    }
    try {
      const parsed: string[] = JSON.parse(text) as string[];
      return parsed;
    } catch (error) {
      return [];
    }
  }

  static real(value: ValueType | Uint8Array | null | undefined): number {
    if (value === null || value === undefined || value === '') {
      return 0;
    }
    return Number(value);
  }
}
