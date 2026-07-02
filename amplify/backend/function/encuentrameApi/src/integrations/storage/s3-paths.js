'use strict';

function normalizeS3Key(value) {
  let key = String(value || '').trim();

  if (!key) return '';

  if (key.startsWith('/')) {
    key = key.slice(1);
  }

  key = key.replace(/\/{2,}/g, '/');

  if (key.startsWith('public/public/')) {
    key = key.replace('public/public/', 'public/');
  }

  return key;
}

const ALLOWED_IMAGE_EXTENSIONS = new Set(['jpg', 'jpeg', 'png', 'webp']);

function isOwnedStallImageKey({ key, userId, stallId }) {
  const raw = String(key || '').trim();
  const owner = String(userId || '').trim();
  const stall = String(stallId || '').trim();

  if (!raw || !owner || !stall || raw.length > 512) return false;
  if (/^https?:\/\//i.test(raw) || raw.includes('..')) return false;
  if (raw.includes('\\') || raw.includes('?') || raw.includes('#')) return false;

  const normalized = normalizeS3Key(raw);
  if (normalized !== raw) return false;

  const prefix = `protected/${owner}/stalls/${stall}/`;
  if (!normalized.startsWith(prefix)) return false;

  const filename = normalized.slice(prefix.length);
  if (!filename || filename.includes('/')) return false;

  const extension = filename.split('.').pop()?.toLowerCase();
  return !!extension && ALLOWED_IMAGE_EXTENSIONS.has(extension);
}

function candidateKeys(value) {
  const key = normalizeS3Key(value);
  if (key.startsWith('protected/') || key.startsWith('private/')) {
    return key ? [key] : [];
  }

  const output = [];

  const push = (candidate) => {
    if (candidate && !output.includes(candidate)) {
      output.push(candidate);
    }
  };

  push(key);

  if (key && !key.startsWith('public/')) {
    push(`public/${key}`);
  }

  if (key && key.startsWith('public/')) {
    push(`public/public/${key.slice('public/'.length)}`);
  }

  if (key && key.startsWith('public/public/')) {
    push(key.replace('public/public/', 'public/'));
  }

  return output.slice(0, 4);
}

module.exports = {
  normalizeS3Key,
  candidateKeys,
  isOwnedStallImageKey,
};
