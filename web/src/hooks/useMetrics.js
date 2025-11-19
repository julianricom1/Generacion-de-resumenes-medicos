import { useState, useEffect } from 'react';
import axios from 'axios';

const DEFAULT_BASE_URL = `http://${window.location.hostname}:8001`;

function useMetrics({ original, generated, doCall = false }) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(false);
  const [metrics, setMetrics] = useState(null);

  useEffect(() => {
    // Example effect: fetch initial data or perform setup
    if (doCall) getAllMetrics(original, generated);
  }, [doCall]);

  // Helper function to ensure input is always an array
  const toArray = input => {
    if (Array.isArray(input)) return input;
    return [input];
  };

  // Helper function to make POST requests
  const makeRequest = async (endpoint, payload) => {
    const response = await axios.post(`${DEFAULT_BASE_URL}${endpoint}`, payload, {
      headers: {
        'Content-Type': 'application/json'
      }
    });
    return response.data;
  };

  // Get all metrics at once
  const getAllMetrics = async (originals, generated, texts = null) => {
    try {
      setLoading(true);
      setError(false);

      const o = toArray(originals);
      const g = toArray(generated);
      if (o.length !== g.length) {
        throw new Error('originals y generated deben tener la misma longitud');
      }

      // Execute all three requests in parallel
      const [relevanceResult, factualityResult, readabilityResult] = await Promise.all([
        makeRequest('/metrics/relevance', {
          texts_original: o,
          texts_generated: g
        }),
        makeRequest('/metrics/factuality', {
          texts_original: o,
          texts_generated: g
        }),
        makeRequest('/metrics/readability', {
          texts: g
        })
      ]);

      // Extract and set the metrics (assuming we want the first value or average)
      const relevanceValue = Array.isArray(relevanceResult.relevance)
        ? relevanceResult.relevance[0] || 0.0
        : relevanceResult.relevance || 0.0;

      const factualityValue = Array.isArray(factualityResult.factuality)
        ? factualityResult.factuality[0] || 0.0
        : factualityResult.factuality || 0.0;

      const readabilityValue = readabilityResult.fkgl?.[0] || 0.0; // Using FKGL as the readability metric

      setMetrics({
        relevance: relevanceValue,
        factuality: factualityValue,
        readability: readabilityValue
      });
    } catch (err) {
      setError(true);
      throw err;
    } finally {
      setLoading(false);
    }
  };

  return {
    loading,
    error,
    metrics
  };
}

export default useMetrics;
