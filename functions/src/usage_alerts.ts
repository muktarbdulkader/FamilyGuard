export type UsageAlertKind = 'highAppUsage' | 'dailyLimitReached';

export function getUsageAlertKind(
  usedMinutes: number,
  effectiveLimitMinutes: number,
  thresholdPercent: number
): UsageAlertKind | null {
  if (
    !Number.isFinite(usedMinutes) ||
    !Number.isFinite(effectiveLimitMinutes) ||
    effectiveLimitMinutes <= 0
  ) {
    return null;
  }

  if (usedMinutes >= effectiveLimitMinutes) {
    return 'dailyLimitReached';
  }

  const threshold = Number.isFinite(thresholdPercent)
    ? Math.min(99, Math.max(1, thresholdPercent))
    : 50;
  const thresholdMinutes = Math.ceil(effectiveLimitMinutes * threshold / 100);
  return usedMinutes >= thresholdMinutes ? 'highAppUsage' : null;
}

export function localDateForTimeZone(date: Date, timeZone: string): string {
  const parts = new Intl.DateTimeFormat('en', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date);
  const year = parts.find((part) => part.type === 'year')?.value;
  const month = parts.find((part) => part.type === 'month')?.value;
  const day = parts.find((part) => part.type === 'day')?.value;
  if (!year || !month || !day) {
    throw new Error(`Could not format local day for ${timeZone}`);
  }
  return `${year}-${month}-${day}`;
}
