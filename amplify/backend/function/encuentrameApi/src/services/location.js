'use strict';

const { LocationClient, SearchPlaceIndexForPositionCommand } = require('@aws-sdk/client-location');

const REGION = process.env.AWS_REGION || process.env.REGION || 'us-east-1';
const INDEX_NAME = process.env.LOCATION_PLACE_INDEX_NAME || '';

const client = new LocationClient({ region: REGION });

function asNumber(x) {
  const n = Number(x);
  return Number.isFinite(n) ? n : null;
}

function mapAddress(place) {
  if (!place) return null;
  return {
    label: place.Label || null,
    street: place.Street || null,
    neighborhood: place.Neighborhood || null,
    municipality: place.Municipality || null,
    subRegion: place.SubRegion || null,
    region: place.Region || null,
    country: place.Country || null,
    postalCode: place.PostalCode || null
  };
}

async function reverseGeocode(lat, lng) {
  if (!INDEX_NAME) return null;

  const la = asNumber(lat);
  const ln = asNumber(lng);
  if (la === null || ln === null) return null;

  try {
    const out = await client.send(new SearchPlaceIndexForPositionCommand({
      IndexName: INDEX_NAME,
      Position: [ln, la],
      MaxResults: 1
    }));

    const place = out?.Results?.[0]?.Place || null;
    if (!place) return null;

    return {
      label: place.Label || null,
      address: mapAddress(place)
    };
  } catch (e) {
    console.log('LOCATION_ERROR', {
      name: e?.name,
      message: e?.message,
      status: e?.$metadata?.httpStatusCode
    });
    return null;
  }
}

module.exports = { reverseGeocode };