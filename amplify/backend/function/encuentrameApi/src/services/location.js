'use strict';

const {
  SearchPlaceIndexForPositionCommand,
} = require('@aws-sdk/client-location');

const config = require('../config');
const { location } = require('./aws');

function asNumber(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
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
    postalCode: place.PostalCode || null,
  };
}

async function reverseGeocode(lat, lng) {
  if (!config.LOCATION_PLACE_INDEX_NAME) return null;

  const latitude = asNumber(lat);
  const longitude = asNumber(lng);

  if (latitude === null || longitude === null) return null;

  try {
    const output = await location.send(
      new SearchPlaceIndexForPositionCommand({
        IndexName: config.LOCATION_PLACE_INDEX_NAME,
        Position: [longitude, latitude],
        MaxResults: 1,
      })
    );

    const place = output?.Results?.[0]?.Place || null;
    if (!place) return null;

    return {
      label: place.Label || null,
      address: mapAddress(place),
    };
  } catch (error) {
    console.log('LOCATION_ERROR', {
      name: error?.name,
      message: error?.message,
      status: error?.$metadata?.httpStatusCode,
    });

    return null;
  }
}

module.exports = {
  reverseGeocode,
};