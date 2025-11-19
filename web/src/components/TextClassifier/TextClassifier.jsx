import { useState, useEffect } from 'react';
import { TextField, Button, Box, Typography, Card, CardContent, Grid } from '@mui/material';
import useClassification from '../../hooks/useClassification';
import ModelInfo from '../ModelInfo/ModelInfo';

function TextClassifier() {
  const [inputText, setInputText] = useState([]);
  const [doCall, setDoCall] = useState(false);

  const { result, metadata } = useClassification({inputText,doCall});

  useEffect(() => {
    if (result) {
      setDoCall(false); // Reset doCall after fetching result
    }
  }, [result, doCall]);

  const handleClassify = () => {
    setDoCall(true);
  };

  return (
    <Box>
      <Grid container spacing={2}>
        <Grid size={9}>
          <Typography variant="h5"><strong>Clasificar Texto</strong></Typography>
        </Grid>
        <Grid size={1}>
          <Button className="clasifyer_button"  variant="contained" color="primary" onClick={handleClassify} sx={{ mt: 2 }}>
            Clasificar
          </Button>
        </Grid>

      </Grid>
      
      <TextField
        fullWidth
        multiline
        rows={6}
        placeholder="Escribe el texto a clasificar"
        value={inputText}
        onChange={(e) => setInputText([e.target.value])}
        sx={{ mt: 2, bgcolor: '#f3e5f5' }}
      />
      
      {result && (
        <Box sx={{ mt: 4 }}>
          <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100%', width: '100%' }}>
            <Card sx={{ display: 'flex',justifyContent: 'center',minWidth: '100%' }} >
              <CardContent>
                <Typography variant="h6">El texto esta expresado en lenguaje <strong>{result.predictions[0]}</strong></Typography>
                <Typography variant="h6">El score obtenido para este texto fue de <strong>{result.scores[0].toFixed(4)}</strong></Typography>
              </CardContent>
            </Card>
          </Box>
          <br />
          <ModelInfo metadata={metadata} />
        </Box>
      )}
    </Box>
  );
}

export default TextClassifier;