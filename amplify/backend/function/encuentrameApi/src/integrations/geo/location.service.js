'use strict';

const {
  LocationClient,
  SearchPlaceIndexForPositionCommand,
} = require('@aws-sdk/client-location');

const { env } = require('../../shared/config/env');

const client = new LocationClient({
  region: env.REGION,
});

async function reverseGeocode(lat, lng) {
  if (!env.LOCATION_PLACE_INDEX_NAME) return null;

  try {
    const out = await client.send(
      new SearchPlaceIndexForPositionCommand({
        IndexName: env.LOCATION_PLACE_INDEX_NAME,
        Position: [lng, lat],
        MaxResults: 1,
      })
    );

    const place = out?.Results?.[0]?.Place || null;
    if (!place) return null;

    return {
      label: place.Label || null,
      address: {
        label: place.Label || null,
        street: place.Street || null,
        neighborhood: place.Neighborhood || null,
        municipality: place.Municipality || null,
        subRegion: place.SubRegion || null,
        region: place.Region || null,
        country: place.Country || null,
        postalCode: place.PostalCode || null,
      },
    };
  } catch (_) {
    return null;
  }
}

module.exports = {
  reverseGeocode,
};