import { Box, Typography, Card, CardContent } from '@mui/material';

function ModelInfo({metadata}) {

  return (
        <>
          <Typography >La version usada del modelo es <strong>{metadata.model_version}</strong></Typography>
          <Typography >Metricas del modelo</Typography>
          <Box sx={{ display: 'flex', gap: 2, mt: 2 }}>
            <Card sx={{ minWidth: '18.8%' }}>
              <CardContent>
                <Typography variant="subtitle1">PR_AUC</Typography>
                <Typography variant="h5">{metadata.metrics.pr_auc.toFixed(4)}</Typography>
              </CardContent>
            </Card>
            <Card sx={{ minWidth: '18.8%' }}>
              <CardContent>
                <Typography variant="subtitle1">ROC_AUC</Typography>
                <Typography variant="h5">{metadata.metrics.roc_auc.toFixed(4)}</Typography>
              </CardContent>
            </Card>
            <Card sx={{ minWidth: '18.8%' }}>
              <CardContent>
                <Typography variant="subtitle1">F1</Typography>
                <Typography variant="h5">{metadata.metrics.f1_score.toFixed(4)}</Typography>
              </CardContent>
            </Card>
            <Card sx={{ minWidth: '18.8%' }}>
              <CardContent>
                <Typography variant="subtitle1">Recall</Typography>
                <Typography variant="h5">{metadata.metrics.recall.toFixed(4)}</Typography>
              </CardContent>
            </Card>
            <Card sx={{ minWidth: '18.8%' }}>
              <CardContent>
                <Typography variant="subtitle1">Accuracy</Typography>
                <Typography variant="h5">{metadata.metrics.accuracy.toFixed(4)}</Typography>
              </CardContent>
            </Card>
          </Box>
        </>
  );
}

export default ModelInfo;