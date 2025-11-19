import { useState } from 'react'
import { Routes, Route } from 'react-router-dom';
import './App.css'
import Layout from './components/Layout/Layout.jsx';
import TextPage from './containers/TextPage/TextPage.jsx';
import FilePage from './containers/FilePage/FilePage.jsx';
import GeneratePage from './containers/GeneratePage/GeneratePage.jsx';

function App() {
  const [count, setCount] = useState(0)

  return (
    <Layout>
      <Routes>
        <Route path="/generar" element={<GeneratePage />} />
        <Route path="/texto" element={<TextPage />} />
        <Route path="/archivo" element={<FilePage />} />
        <Route path="*" element={<GeneratePage />} /> {/* Default to generate page */}
      </Routes>
    </Layout>
  );

}

export default App
