import { useState, useEffect } from 'react';
import axios from 'axios';

const domain = import.meta.env.VITE_METRICS_DOMAIN;
const DEFAULT_BASE_URL = domain || `http://${window.location.hostname}:8001`;

function useMetrics({ text, doCall = false }) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(false);
  const [readability, setReadability] = useState(null);
  const [category, setCategory] = useState(null);

  useEffect(() => {
    // Example effect: fetch initial data or perform setup
    if (doCall) getReadability(text);
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
  const getReadability = async text => {
    try {
      setLoading(true);
      setError(false);

      const t = toArray(text);
      if (t.length === 0) {
        throw new Error('El texto no puede estar vacío');
      }

      // Execute all three requests in parallel
      const [readabilityResult] = await Promise.all([
        makeRequest('/metrics/readability', {
          texts: t
        })
      ]);

      const readabilityValue = readabilityResult.fkgl?.[0] || 0.0; // Using FKGL as the readability metric

      setReadability(readabilityValue);
      getCategory(readabilityValue);
    } catch (err) {
      setError(true);
      throw err;
    } finally {
      setLoading(false);
    }
  };
  const getCategory = readability => {
    console.log('Readability:', readability);
    if (readability >= 15) {
      setCategory('Postgrado');
    } else if (readability >= 12 && readability < 15) {
      setCategory('Pregrado');
    } else if (readability >= 9 && readability < 12) {
      setCategory('Colegio 9-10 grado');
    } else if (readability >= 6 && readability < 9) {
      setCategory('Colegio 6-8 grado');
    } else if (readability >= 3 && readability < 6) {
      setCategory('Escuela');
    } else if (readability >= 0 && readability < 3) {
      setCategory('Jardin/Escuela primaria');
    }
  };

  return {
    loading,
    error,
    readability,
    category
  };
}

export default useMetrics;
