import React from 'react';
import {
    createBrowserRouter,
    createRoutesFromElements,
    Route,
    RouterProvider
} from 'react-router-dom';

export const Router = props => {
    return (
        <RouterProvider
            router={createBrowserRouter(
                createRoutesFromElements(
                    <Route path="*" element={props.children} />
                )
            )}
        />
    );
}