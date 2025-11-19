import { useState, useEffect } from 'react';
import axios from 'axios';

function useGeneration({ inputText, doCall = false, modelName }) {
  const [result, setResult] = useState(null);
  const [metadata, setMetadata] = useState({});
  const [error, setError] = useState(false);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    // Example effect: fetch initial data or perform setup
    if (doCall) fetchPrediction(inputText);
  }, [doCall]);

  const API_DOMAIN = `http://${window.location.hostname}:8002`; // Default to "http://localhost" if not set
  //const PORT = process.env.REACT_APP_PORT || "8000";

  const fetchPrediction = async text => {
    try {
      setLoading(true);
      const response = await axios.post(`${API_DOMAIN}/api/v1/generate`, {
        inputs: text,
        model: modelName
      });
      setResult({
        generation: response.data.generation
      });
      setMetadata(response.data.metadata);
      setError(false);
      setLoading(false);
    } catch (error) {
      console.error('Error fetching prediction:', error);
      setError(true);
      setLoading(false);
    }
  };

  return { result, metadata, error, loading };
}

export default useGeneration;
