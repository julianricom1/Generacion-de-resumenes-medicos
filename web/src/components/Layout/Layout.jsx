import SideMenu from '../SideMenu/SideMenu.jsx';
import { Box } from '@mui/material';

function Layout({ children }) {
  return (
    <Box sx={{ display: 'flex', height: '100vh'}}>
      <SideMenu />
      <Box component="main" sx={{ flexGrow: 1, p: 3 }}>
        {children}
      </Box>
    </Box>
  );
}

export default Layout;