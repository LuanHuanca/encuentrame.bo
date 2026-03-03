'use strict';

function normalizeS3Key(k) {
  let key = String(k || '').trim();
  if (!key) return '';
  if (key.startsWith('/')) key = key.slice(1);
  key = key.replace(/\/{2,}/g, '/');
  if (key.startsWith('public/public/')) key = key.replace('public/public/', 'public/');
  return key;
}

function candidateKeys(k) {
  const key = normalizeS3Key(k);
  const out = [];
  const push = (x) => { if (x && !out.includes(x)) out.push(x); };

  push(key);

  if (key && !key.startsWith('public/')) push(`public/${key}`);
  if (key && key.startsWith('public/')) push(`public/public/${key.slice('public/'.length)}`);
  if (key && key.startsWith('public/public/')) push(key.replace('public/public/', 'public/'));

  return out.slice(0, 4);
}

module.exports = { normalizeS3Key, candidateKeys };