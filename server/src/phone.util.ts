import { BadRequestException } from '@nestjs/common';

export function normalizeTurkishPhone(input: string) {
  let digits = input.replace(/\D/g, '');
  if (digits.startsWith('0090')) digits = digits.slice(2);
  if (digits.startsWith('0') && digits.length === 11) digits = `90${digits.slice(1)}`;
  if (digits.length === 10) digits = `90${digits}`;
  if (!digits.startsWith('90') || digits.length !== 12) {
    throw new BadRequestException('Geçerli bir Türkiye telefon numarası gir.');
  }
  return `+${digits}`;
}
