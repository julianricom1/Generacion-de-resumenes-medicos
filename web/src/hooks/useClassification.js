import { useState, useEffect } from 'react';
import axios from 'axios';

function useClassification({ inputText, doCall = false }) {
  const [result, setResult] = useState(null);
  const [metadata, setMetadata] = useState({});
  const [error, setError] = useState(false);

  useEffect(() => {
    // Example effect: fetch initial data or perform setup
    if (doCall) fetchPrediction(inputText);
  }, [doCall]);

  const domain = import.meta.env.VITE_CLASSIFICATION_DOMAIN;
  const API_DOMAIN = domain || `http://${window.location.hostname}:8001`;

  const fetchPrediction = async text => {
    try {
      const response = await axios.post(
        //`${API_DOMAIN}:${PORT}/api/v1/predict`,
        `${API_DOMAIN}/api/v1/predict`,
        {
          inputs: text
        }
      );
      setResult({
        predictions: response.data.predictions.map(clasification =>
          clasification === 1 ? 'Tecnico' : 'Plano'
        ),
        scores: response.data.scores
      });
      setMetadata(response.data.metadata);
    } catch (error) {
      setError(true);
      console.error('Error fetching prediction:', error);
    }
  };

  return { result, metadata, error };
}

export default useClassification;
