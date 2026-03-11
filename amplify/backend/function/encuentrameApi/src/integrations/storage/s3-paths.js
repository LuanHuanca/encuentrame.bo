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

function candidateKeys(value) {
  const key = normalizeS3Key(value);
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
};