const test = require('node:test');
const assert = require('node:assert/strict');
const {
  getUsageAlertKind,
  localDateForTimeZone,
} = require('../lib/usage_alerts');

test('usage alerts fire at configured threshold and at the limit', () => {
  assert.equal(getUsageAlertKind(29, 60, 50), null);
  assert.equal(getUsageAlertKind(30, 60, 50), 'highAppUsage');
  assert.equal(getUsageAlertKind(59, 60, 50), 'highAppUsage');
  assert.equal(getUsageAlertKind(60, 60, 50), 'dailyLimitReached');
});

test('threshold calculation rounds up and clamps to the valid range', () => {
  assert.equal(getUsageAlertKind(20, 41, 50), null);
  assert.equal(getUsageAlertKind(21, 41, 50), 'highAppUsage');
  assert.equal(getUsageAlertKind(1, 60, 0), 'highAppUsage');
});

test('local day follows the child device time zone', () => {
  assert.equal(
    localDateForTimeZone(new Date('2026-10-19T22:30:00.000Z'), 'Africa/Addis_Ababa'),
    '2026-10-20'
  );
});
