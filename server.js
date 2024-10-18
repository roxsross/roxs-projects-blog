const express = require('express');
const path = require('path');
require('dotenv').config();

const app = express();
const port = process.env.PORT || 3000;

app.use(express.static('public'));
app.use('/src', express.static(path.join(__dirname, 'src')));

app.get('/package.json', (req, res) => {
    res.sendFile(path.join(__dirname, 'package.json'));
});

app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).send('Algo salió mal!');
});

app.listen(port, () => {
    console.log(`Servidor escuchando en http://localhost:${port}`);
});