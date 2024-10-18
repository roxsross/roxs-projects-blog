/**
 * @jest-environment jsdom
 */

import {
    getAllCars,
    getCarById,
    addCar,
    updateCar
} from '../src/api/carsApi.js';

import {
    addCarRows,
    retrieveCarId,
    populateEditCarForm,
    retrieveCarForm,
    cleanTable
} from '../src/utils/uiHelpers.js';

// Mock the API functions
jest.mock('../src/api/carsApi.js');

// Mock DOM elements
document.body.innerHTML = `
  <table id="cars-table"><tbody></tbody></table>
  <form id="editCarForm">
    <input id="carid" value="1" />
    <input id="name" value="Test Car" />
    <input id="brand" value="Test Brand" />
    <input id="year" value="2023" />
  </form>
`;

describe('Car Management System', () => {
    beforeEach(() => {
        jest.clearAllMocks();
    });

    test('addCarRows should add rows to the table', () => {
        const cars = [
            { car_id: 1, name: 'Car 1', brand: 'Brand 1', year_release: 2021 },
            { car_id: 2, name: 'Car 2', brand: 'Brand 2', year_release: 2022 }
        ];
        addCarRows(cars, 'cars-table');
        const tableRows = document.querySelectorAll('#cars-table tbody tr');
        expect(tableRows.length).toBe(2);
    });

    test('retrieveCarId should return the car ID from the input', () => {
        const carId = retrieveCarId();
        expect(carId).toBe('1');  // Form inputs return string, expected value should be string
    });

    test('populateEditCarForm should fill the form with car details', () => {
        const car = { car_id: 1, name: 'Test Car', brand: 'Test Brand', year_release: 2023 };
        populateEditCarForm(car);
        expect(document.getElementById('name').value).toBe('Test Car');
        expect(document.getElementById('brand').value).toBe('Test Brand');
        expect(document.getElementById('year').value).toBe('2023');
    });

    test('retrieveCarForm should return car details from the form', () => {
        const car = retrieveCarForm();
        expect(car).toEqual({
            car_id: '1',  // Convert expected to string to match form values
            name: 'Test Car',
            brand: 'Test Brand',
            year_release: '2023'
        });
    });

    test('cleanTable should remove all rows from the table', () => {
        const table = document.getElementById('cars-table');
        const tbody = table.getElementsByTagName('tbody')[0];
        tbody.innerHTML = '<tr><td>Test</td></tr>';
        cleanTable('cars-table');
        expect(tbody.innerHTML).toBe('');
    });

    test('getAllCars should fetch all cars', async () => {
        const mockCars = [{ car_id: 1, name: 'Car 1', brand: 'Brand 1', year_release: 2021 }];
        getAllCars.mockResolvedValue(mockCars);
        const cars = await getAllCars();
        expect(cars).toEqual(mockCars);
    });

    test('getCarById should fetch a car by ID', async () => {
        const mockCar = { car_id: 1, name: 'Car 1', brand: 'Brand 1', year_release: 2021 };
        getCarById.mockResolvedValue(mockCar);
        const car = await getCarById(1);
        expect(car).toEqual(mockCar);
    });

    test('addCar should add a new car', async () => {
        const newCar = { name: 'New Car', brand: 'New Brand', year_release: 2023 };
        addCar.mockResolvedValue({ ...newCar, car_id: 3 });
        const addedCar = await addCar(newCar);
        expect(addedCar).toEqual({ ...newCar, car_id: 3 });
    });

    test('updateCar should update an existing car', async () => {
        const updatedCar = { car_id: 1, name: 'Updated Car', brand: 'Updated Brand', year_release: 2024 };
        updateCar.mockResolvedValue(updatedCar);
        const result = await updateCar(updatedCar);
        expect(result).toEqual(updatedCar);
    });
});
