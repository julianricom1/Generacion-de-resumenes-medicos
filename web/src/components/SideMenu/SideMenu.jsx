import React, { useState } from 'react';
import { Box, List, ListItem, ListItemButton, ListItemIcon, ListItemText, Typography, Collapse } from '@mui/material';
import TextFieldsIcon from '@mui/icons-material/TextFields';
import FolderIcon from '@mui/icons-material/Folder';
import ExpandLess from '@mui/icons-material/ExpandLess';
import ExpandMore from '@mui/icons-material/ExpandMore';
import ClassIcon from '@mui/icons-material/Class';
import GeneratingTokensIcon from '@mui/icons-material/GeneratingTokens';
import { useNavigate } from 'react-router-dom';

function SideMenu() {
    const navigate = useNavigate();
    const [open, setOpen] = useState(false);

    const handleClick = () => {
        setOpen(!open);
    };

    return (
        
        <Box className="menu" sx={{ width: 250, bgcolor: 'background.paper' }}>
            <Typography variant="h6"><strong>Clasificacion de textos Medicos</strong></Typography>
            <List>
                <ListItem disablePadding>
                    <ListItemButton onClick={() => navigate('/generar')}>
                        <ListItemIcon>
                            <GeneratingTokensIcon />
                        </ListItemIcon>
                        <ListItemText primary="Generar" />
                    </ListItemButton>
                </ListItem>
                <ListItem disablePadding>
                    <ListItemButton onClick={handleClick}>
                        <ListItemIcon>
                            <ClassIcon />
                        </ListItemIcon>
                        <ListItemText primary="Clasificacion" />
                        {open ? <ExpandLess /> : <ExpandMore />}
                    </ListItemButton>
                </ListItem>
                <Collapse in={open} timeout="auto" unmountOnExit>
                    <List component="div" disablePadding>
                        <ListItem disablePadding>
                            <ListItemButton sx={{ pl: 4 }} onClick={() => navigate('/texto')}>
                                <ListItemIcon>
                                    <TextFieldsIcon />
                                </ListItemIcon>
                                <ListItemText primary="Texto" />
                            </ListItemButton>
                        </ListItem>
                        <ListItem disablePadding>
                            <ListItemButton sx={{ pl: 4 }} onClick={() => navigate('/archivo')}>
                                <ListItemIcon>
                                    <FolderIcon />
                                </ListItemIcon>
                                <ListItemText primary="Archivo" />
                            </ListItemButton>
                        </ListItem>
                    </List>
                </Collapse>
                
            </List>
        </Box>
    );
}

export default SideMenu;