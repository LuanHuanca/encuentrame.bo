'use strict';

const {
  BedrockRuntimeClient,
  InvokeModelCommand,
} = require('@aws-sdk/client-bedrock-runtime');

const { env } = require('../../shared/config/env');

const client = new BedrockRuntimeClient({
  region: env.REGION,
});

function extractJson(text) {
  if (!text) return null;

  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');

  if (start !== -1 && end !== -1 && end > start) {
    return text.substring(start, end + 1);
  }

  return null;
}

async function extractInventory({ rawText, labels }) {
  if (!env.BEDROCK_MODEL_ID) return null;

  const prompt = `Eres un extractor de inventario. La app convertirá tu respuesta en una tabla.

TAREA:
- Lee el texto en español y conviértelo en productos separados.
- Si el texto dice "10 zapatos, una polera y una botella", deben salir 3 filas:
  - zapato qty 10
  - polera qty 1
  - botella qty 1

REGLAS:
- Devuelve SOLO JSON válido.
- No inventes productos.
- Si no hay cantidad, asume 1.
- Normaliza:
  - tomatodo/termo -> botella
  - camiseta/poleras -> polera
  - botas -> bota
  - zapatos -> zapato
- Fusiona duplicados.
- Ignora persona/hombre/mujer/niño.

FORMATO:
{
  "items": [
    { "canonical": "string", "display": "string", "qty": number }
  ]
}

Texto:
"""${String(rawText || '').slice(0, 4000)}"""

Labels:
${JSON.stringify(labels || [])}`;

  const isTitan = env.BEDROCK_MODEL_ID.startsWith('amazon.');

  const body = isTitan
    ? JSON.stringify({
        inputText: prompt,
        textGenerationConfig: {
          maxTokenCount: 700,
          temperature: 0,
          topP: 1,
        },
      })
    : JSON.stringify({
        anthropic_version: 'bedrock-2023-05-31',
        max_tokens: 700,
        temperature: 0,
        messages: [{ role: 'user', content: prompt }],
      });

  const response = await client.send(
    new InvokeModelCommand({
      modelId: env.BEDROCK_MODEL_ID,
      contentType: 'application/json',
      accept: 'application/json',
      body,
    })
  );

  const raw = Buffer.from(response.body).toString('utf8');
  const parsed = JSON.parse(raw);

  const outText = isTitan
    ? parsed?.results?.[0]?.outputText || ''
    : parsed?.content?.[0]?.text || '';

  const jsonString = extractJson(outText);
  if (!jsonString) return null;

  const object = JSON.parse(jsonString);
  if (!object || !Array.isArray(object.items)) return null;

  return object;
}

module.exports = {
  extractInventory,
};