import React from 'react'
import { createRoot } from 'react-dom/client'
import './application.css'

const root = document.getElementById('root')
if (!root) throw new Error('No #root element')
createRoot(root).render(<React.StrictMode><div className="p-4 text-white bg-slate-950 min-h-screen">Loading…</div></React.StrictMode>)
