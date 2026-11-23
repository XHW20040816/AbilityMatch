import { ValuesBucket } from '@kit.ArkData';
import { Constants } from '../common/Constants';
import { DbHelper } from '../common/DbHelper';
import { Company } from '../model/Entity';
import { BaseRepository } from './BaseRepository';

export class CompanyRepository {
  async list(): Promise<Company[]> {
    const rows: ValuesBucket[] = await DbHelper.query(
      `SELECT * FROM ${Constants.T_COMPANY} ORDER BY id ASC`, []
    );
    return rows.map((row: ValuesBucket) => this.toEntity(row));
  }

  async getById(id: number): Promise<Company | null> {
    const row: ValuesBucket | null = await DbHelper.queryOne(
      `SELECT * FROM ${Constants.T_COMPANY} WHERE id = ?`, [id]
    );
    return row === null ? null : this.toEntity(row);
  }

  async insert(company: Company): Promise<number> {
    const now: number = Date.now();
    return await DbHelper.insert(Constants.T_COMPANY, {
      company_name: company.companyName,
      industry: company.industry,
      scale: company.scale,
      contact_person: company.contactPerson,
      contact_phone: company.contactPhone,
      address: company.address,
      create_time: now,
      update_time: now
    });
  }

  async update(company: Company): Promise<void> {
    await DbHelper.update(Constants.T_COMPANY, {
      company_name: company.companyName,
      industry: company.industry,
      scale: company.scale,
      contact_person: company.contactPerson,
      contact_phone: company.contactPhone,
      address: company.address,
      update_time: Date.now()
    }, 'id = ?', [company.id]);
  }

  async remove(id: number): Promise<void> {
    await DbHelper.remove(Constants.T_COMPANY, 'id = ?', [id]);
  }

  private toEntity(row: ValuesBucket): Company {
    return {
      id: BaseRepository.num(row['id']),
      companyName: BaseRepository.str(row['company_name']),
      industry: BaseRepository.str(row['industry']),
      scale: BaseRepository.str(row['scale']),
      contactPerson: BaseRepository.str(row['contact_person']),
      contactPhone: BaseRepository.str(row['contact_phone']),
      address: BaseRepository.str(row['address'])
    };
  }
}
