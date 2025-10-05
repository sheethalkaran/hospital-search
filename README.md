# Hospital Finder

A full-stack application to help users find hospitals nearby or search for hospitals across India. Built with Node.js/Express backend and Flutter frontend.

## Features
- Search hospitals by name, state, district, category, and more
- Find nearby hospitals using your location (with adjustable radius)
- View hospital details, specialties, available beds, and accreditation
- Interactive map view for hospital locations
- Statistics and analytics for hospitals

## Tech Stack
- **Backend:** Node.js, Express, MongoDB
- **Frontend:** Flutter (Android, iOS, Web, Desktop)
- **Data:** hospitals.xlsv (imported to MongoDB)

## Project Structure
├── backend/
│   ├── .env                 # Backend environment configuration
│   ├── package.json         # Backend dependencies and scripts
│   ├── server.js           # Main backend server file
│   ├── data/
│   │   └── hospitals.xlsx   # Hospital data 
│   └── scripts/
│       └── importData.js    # Data import script
│
└── frontend/               # Flutter frontend application
    ├── lib/               # Flutter source code
    ├── test/             # Frontend tests
    ├── pubspec.yaml      # Flutter dependencies
    └── README.md         # Frontend documentation