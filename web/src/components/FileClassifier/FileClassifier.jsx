import { useState, useEffect } from 'react';
import { Button, Box, Typography, Card, CardContent, Grid } from '@mui/material';
import useClassification from '../../hooks/useClassification';
import { DataGrid } from '@mui/x-data-grid';
import Papa from "papaparse";
import ModelInfo from '../ModelInfo/ModelInfo';

const columns = [
  { field: 'id', headerName: 'ID', width: 90 },
  {
    field: 'texto',
    headerName: 'Texto',
    flex: 1, // Use flex for dynamic width
    minWidth: 200, // Minimum width for responsiveness
    editable: false,
  },
  {
    field: 'clasificacion',
    headerName: 'Clasificacion',
    flex: 0.5, // Use flex for dynamic width
    minWidth: 150, // Minimum width for responsiveness
    editable: false,
  },
  {
    field: 'score',
    headerName: 'Score',
    flex: 0.5, // Use flex for dynamic width
    minWidth: 150, // Minimum width for responsiveness
    editable: false,
  }
];

function FileClassifier() {
  const [file, setFile] = useState(null);
  const [doCall, setDoCall] = useState(false);
  const [inputText, setInputText] = useState([]);

  const [rows, setRows] = useState([]);

  const { result, metadata } = useClassification({inputText, doCall});

  useEffect(() => {
    if (result) {
      console.log("Result updated:", result);
      const newRows = inputText.map((text, index) => ({
        id: index + 1,
        texto: text,
        clasificacion: result.predictions[index] || 'N/A',
        score: result.scores[index].toFixed(4) || 'N/A'
      }));
      setRows(newRows);
      setDoCall(false); // Reset doCall after fetching result
    }
  }, [result, doCall]);

  const handleFileChange = (e) => {
    setFile(e.target.files[0]);
  };

  const handleClassify = () => {
    if (file) {
      readFile(file);
    }
  };

  const readFile = (file) => {
    Papa.parse(file, {
      header: true, // Assumes the CSV has headers
      complete: function (results) {
        const textValues = results.data
          .filter((row) => row.text !== undefined) // Ensure "text" exists
          .map((row) => row.text);
        setInputText(textValues);
        setDoCall(true);
      },
      error: function (error) {
        console.error("Error parsing CSV:", error);
      },
    });
  };

  return (
    <Box>
      <Grid container spacing={2}>
        <Grid size={9}>
          <Typography variant="h5"><strong>Clasificar Archivo</strong></Typography>
        </Grid>
        <Grid size={1}>
          <Button className="clasifyer_button" variant="contained" color="primary" onClick={handleClassify} sx={{ mt: 2 }}>
            Clasificar
          </Button>
      </Grid>

      </Grid>
      <Box sx={{ mt: 4 }}>
        <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100%', width: '100%' }}>
          <Card sx={{ display: 'flex',justifyContent: 'center',minWidth: '100%' }} >
            <CardContent>
              <input type="file" accept=".csv" onChange={handleFileChange} />
            </CardContent>
          </Card>
        </Box>
      </Box>
      
      {result && (
        <Box sx={{ mt: 4 }}>
          <DataGrid
            rows={rows}
            columns={columns}
            initialState={{
              pagination: {
                paginationModel: {
                  pageSize: 5,
                },
              },
            }}
            pageSizeOptions={[5]}
            checkboxSelection
            disableRowSelectionOnClick
          />
          <br />
          <ModelInfo metadata={metadata} />
        </Box>
      )}
    </Box>
  );
}

export default FileClassifier;