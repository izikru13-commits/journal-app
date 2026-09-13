// Continents for the easiest level of the globe game, and as permanent orientation labels
// on the globe itself. Coordinates are a representative interior point, not a true centroid,
// so a reasonable click anywhere on the landmass scores well.
window.CONTINENTS = [
    { code: 'africa', nameHe: 'אפריקה', lat: 4, lng: 21, isContinent: true, difficulty: 1 },
    { code: 'asia', nameHe: 'אסיה', lat: 34, lng: 90, isContinent: true, difficulty: 1 },
    { code: 'europe', nameHe: 'אירופה', lat: 50, lng: 15, isContinent: true, difficulty: 1 },
    { code: 'north-america', nameHe: 'צפון אמריקה', lat: 45, lng: -100, isContinent: true, difficulty: 1 },
    { code: 'south-america', nameHe: 'דרום אמריקה', lat: -15, lng: -60, isContinent: true, difficulty: 1 },
    { code: 'oceania', nameHe: 'אוקיאניה', lat: -25, lng: 135, isContinent: true, difficulty: 1 },
    { code: 'antarctica', nameHe: 'אנטארקטיקה', lat: -82, lng: 0, isContinent: true, difficulty: 1 },
];
