import { useState, useEffect } from 'react';
import {TextField, Button, Box, Typography, Card, CardContent, Grid, CircularProgress, Backdrop, FormControl, InputLabel, Select, MenuItem } from '@mui/material';
import useGeneration from '../../hooks/useGeneration';
import useReadability from '../../hooks/useReadability';
import useClassification from '../../hooks/useClassification';

import { SupportedModels } from '../../types/supportedModel';

function GeneratePage() {
   const [inputText, setInputText] = useState([]);
  const [doCall, setDoCall] = useState(false);
  const [isTechnical, setIsTechnical] = useState(false);
  const [doCallMetrics, setDoCallMetrics] = useState(false);
  const [selectedModel, setSelectedModel] = useState(SupportedModels.OLLAMA_FINNED_TUNNED);

  //Se clasifica texto de entrada y su legibilidad
  const { result:classification, metadata } = useClassification({inputText,doCall});
  const { loading: loading_readability, error: error_readability, readability, category: originalTextCategory } = useReadability({ text: inputText, doCall });

  // Generacion de texto y calculo de metricas
  const { result: result, loading: loading, error: error } = useGeneration({inputText,doCall:(doCall && isTechnical), modelName: selectedModel.name });
  const { loading: loading_readability_generated, error: error_readability_generated, readability: readability_generated, category: generatedTextCategory } = useReadability({ text: result?.generation, doCall: (doCallMetrics && isTechnical) });
  useEffect(() => { 
    if (classification && classification.predictions[0] === 'Tecnico') {
      setIsTechnical(true);
    } else {
      setIsTechnical(false);
    }
  }, [classification]);
  
  useEffect(() => {
    if (result) {
      setDoCall(false); // Reset doCall after fetching both results
      setDoCallMetrics(true); // Trigger metrics calculation
    }
  }, [result, doCall]);

  useEffect(() => {
    if (error) {
      setDoCall(false); // Reset doCall if there's an error
    }
  }, [error]);

  useEffect(() => {
    if (readability_generated || error_readability_generated) {
      setDoCallMetrics(false); // Reset doCallMetrics after fetching metrics
    }
  }, [readability_generated, error_readability_generated, doCallMetrics]);

  const handleClassify = () => {
    setDoCall(true);
  };

  const handleModelChange = (event) => {
    setSelectedModel(event.target.value);
  };

  // Show loading when either generation or metrics are loading
  const isLoading = loading || loading_readability_generated;

  const availableModels = Object.entries(SupportedModels)

  return (
    <Box>
      <Backdrop
        sx={{
          color: '#fff',
          zIndex: (theme) => theme.zIndex.drawer + 1,
          position: 'absolute',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          backgroundColor: 'rgba(0, 0, 0, 0.5)',
          display: 'flex',
          flexDirection: 'column',
          gap: 2
        }}
        open={isLoading}
      >
        <CircularProgress color="inherit" size={60} />
        <Typography color="inherit" variant="h6">
          {(loading) ? 'Generando texto...' : loading_readability_generated ? 'Calculando métricas...' : 'Cargando...'}
        </Typography>
      </Backdrop>

      <Grid container spacing={2} alignItems="center">
        <Grid size={6}>
          <Typography variant="h5"><strong>Generar Texto</strong></Typography>
        </Grid>
        <Grid size={3}>
          <FormControl fullWidth size="small">
            <InputLabel>Modelo</InputLabel>
            <Select
              value={selectedModel}
              label="Modelo"
              onChange={handleModelChange}
            >
              {availableModels.map(([key, value]) => (
                <MenuItem key={key} value={value}>
                  {value.displayName}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
        </Grid>
        <Grid size={3}>
          <Button 
            className="clasifyer_button"  
            variant="contained" 
            color="primary" 
            onClick={handleClassify} 
            sx={{ mt: 2 }}
            fullWidth
          >
            Generar
          </Button>
        </Grid>
      </Grid>
      
      <TextField
        fullWidth
        multiline
        rows={6}
        placeholder="¿Que texto medico quieres generar?"
        value={inputText}
        onChange={(e) => setInputText([e.target.value])}
        sx={{ mt: 2, bgcolor: '#f3e5f5' }}
      />

      {/* Readability Metrics Section */}
      {!loading_readability && !error_readability && readability && classification&& (
        <Box sx={{ mt: 4 }}>
          <Grid container spacing={2}>
            <Grid size={4}>
              <Card>
                <CardContent sx={{ textAlign: 'center' }}>
                  <Typography variant="subtitle1" color="text.secondary">
                    Legibilidad del Texto Original
                  </Typography>
                  <Typography variant="h4" color="success.main" sx={{ fontWeight: 'bold' }}>
                    {readability.toFixed(4)}
                  </Typography>
                </CardContent>
              </Card>
            </Grid>
            
            <Grid size={4}>
              <Card>
                <CardContent sx={{ textAlign: 'center' }}>
                  <Typography variant="subtitle1" color="text.secondary">
                    El Texto Original es de tipo
                  </Typography>
                  <Typography variant="h4" color="success.main" sx={{ fontWeight: 'bold' }}>
                    {classification.predictions[0]}
                  </Typography>
                </CardContent>
              </Card>
            </Grid>
            <Grid size={4}>
              <Card>
                <CardContent sx={{ textAlign: 'center' }}>
                  <Typography variant="subtitle1" color="text.secondary">
                    El Texto original corresponde al nivel educativo de
                  </Typography>
                  <Typography variant="h4" color="success.main" sx={{ fontWeight: 'bold' }}>
                    {originalTextCategory}
                  </Typography>
                </CardContent>
              </Card>
            </Grid>
          </Grid>
          {classification.predictions[0] === 'Plano' && (
            <Typography variant="h6" color="error.main" sx={{ mt: 2 }}>
              Nota: El texto original ya es de tipo "Plano". No se generara un nuevo texto.
            </Typography>
          )}
        </Box>
      )}

      {/* Results Section */}
      {(result) && (
        <Box sx={{ mt: 4 }}>
          <Typography variant="h6" sx={{ mb: 3 }}>
            <strong>Resultados de Generación</strong>
          </Typography>
          
          <Grid container spacing={3}>

            {/* Right Split - Commercial Model */}
            <Grid size={12}>
              <Card sx={{ height: '100%', minHeight: 300 }}>
                <CardContent>
                  <Typography variant="h6" sx={{ mb: 2, color: 'secondary.main', fontWeight: 'bold' }}>
                    ✨ {selectedModel.displayName}
                  </Typography>
                  
                  {loading ? (
                    <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: 200 }}>
                      <CircularProgress />
                    </Box>
                  ) : result ? (
                    <Typography sx={{ lineHeight: 1.6 }}>
                      {result.generation}
                    </Typography>
                  ) : (
                    <Typography color="text.secondary" sx={{ fontStyle: 'italic' }}>
                      Esperando generación...
                    </Typography>
                  )}
                </CardContent>
              </Card>
            </Grid>
          </Grid>
        </Box>
      )}

      {/* Generated Metrics Section */}
      {!loading_readability_generated && !error_readability_generated && readability_generated && (
        <Box sx={{ mt: 4 }}>
          <Typography variant="h6" sx={{ mb: 2 }}>
            <strong>Métricas del Texto Generado</strong>
          </Typography>
          <Grid container spacing={2}>
            <Grid size={4}>
              <Card>
                <CardContent sx={{ textAlign: 'center' }}>
                  <Typography variant="subtitle1" color="text.secondary">
                    Legibilidad del Texto Generado
                  </Typography>
                  <Typography variant="h4" color="success.main" sx={{ fontWeight: 'bold' }}>
                    {readability_generated.toFixed(4)}
                  </Typography>
                </CardContent>
              </Card>
            </Grid>
            <Grid size={4}>
              <Card>
                <CardContent sx={{ textAlign: 'center' }}>
                  <Typography variant="subtitle1" color="text.secondary">
                   El Texto Generado corresponde al nivel educativo de
                  </Typography>
                  <Typography variant="h4" color="success.main" sx={{ fontWeight: 'bold' }}>
                    {generatedTextCategory}
                  </Typography>
                </CardContent>
              </Card>
            </Grid>
            <Grid size={4}>
              <Card>
                <CardContent sx={{ textAlign: 'center' }}>
                  <Typography variant="subtitle1" color="text.secondary">
                    El Texto original corresponde al nivel educativo de
                  </Typography>
                  <Typography variant="h4" color="success.main" sx={{ fontWeight: 'bold' }}>
                    {originalTextCategory}
                  </Typography>
                </CardContent>
              </Card>
            </Grid>
          </Grid>
        </Box>
      )}
    </Box>
  );
}

export default GeneratePage;