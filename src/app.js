import { 
    addCarRows, 
    retrieveCarId, 
    populateEditCarForm,
    retrieveCarForm,
    cleanTable,
} from './utils/uiHelpers.js';

import { 
   getAllCars,
   getCarById,
   addCar 
} from './api/carsApi.js';

async function loadVersion() {
    try {
        const response = await fetch('/package.json');
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        const data = await response.json();
        document.getElementById('version-badge').textContent = `v${data.version}`;
    } catch (error) {
        console.error('Error al cargar la versión:', error);
    }
}

function clearForm() {
    const form = document.getElementById('editCarForm');
    form.reset();
    form.classList.remove('was-validated');
    Array.from(form.elements).forEach((element) => {
        element.classList.remove('is-invalid');
        element.classList.remove('is-valid');
    });
}

document.addEventListener('DOMContentLoaded', async () => {
    console.log('./app.js loaded');
    await loadVersion();

    const buttonLoadCars = document.getElementById('loadcars');
    buttonLoadCars.addEventListener('click', (event) => {
        event.stopPropagation();
        cleanTable('cars-table');
        getAllCars().then((result) => {
            addCarRows(result, 'cars-table');
        });
    });

    const buttonLoadCar = document.getElementById('loadcar');
    buttonLoadCar.addEventListener('click', (event) => {
        event.stopPropagation();
        const carId = retrieveCarId();
        getCarById(carId)
            .then((r) => populateEditCarForm(r));
    });

    const buttonAddCar = document.getElementById('add');
    buttonAddCar.addEventListener('click', (event) => {
        event.stopPropagation();
        event.preventDefault();
        const form = document.getElementById('editCarForm');
        if (form.checkValidity()) {
            const car = retrieveCarForm();
            addCar(car)
                .then((_) => {
                    cleanTable('cars-table');
                    return getAllCars();
                })
                .then((result) => {
                    addCarRows(result, 'cars-table');
                    clearForm(); // Clear the form after successfully adding/updating a car
                });
        } else {
            form.classList.add('was-validated');
        }
    });
});